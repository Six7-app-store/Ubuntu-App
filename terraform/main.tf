terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10"
    }
  }
}

provider "openstack" {
  cloud = "openstack"
  # Auth via OS_CLOUD + clouds.yaml (oder OS_* env vars)
}

############################
# APP-DEFAULTS (vom App-Entwickler vorgegeben)
############################

locals {
  # Diese Werte sind App-spezifisch und werden vom App-Entwickler definiert
  app_name = "ubuntu-user"
  flavor   = "gp1.small"
  key_pair = "" # Leer = nur Passwort-Auth

  # Keine Floating IP. Sie liesse sich in diesem Projekt zwar anlegen,
  # aber nicht zuweisen - zwischen VM-Subnetz und externem Netz fehlt
  # der Router ("External network ... is not reachable from subnet").
  #
  # Erreichbar ist die Instanz ueber die feste Adresse der gewaehlten
  # Familie (var.ip_mode). Die IPv4 im DHBWV6-Netz ist eine private
  # NAT-Adresse (10.200.x.x) und taugt nicht als Verbindungsziel -
  # oeffentliches IPv4 kommt nur aus einem eigenen IPv4-Netz wie DHBWv4.
  enable_floating_ip = false

  metadata = {}
}

############################
# ADRESSFAMILIEN (var.ip_mode)
############################

locals {
  ethertypes = {
    ipv4 = ["IPv4"]
    ipv6 = ["IPv6"]
    dual = ["IPv4", "IPv6"]
  }[var.ip_mode]

  # Hauptschnittstelle. Bei dual liegt sie im IPv6-Netz: dessen private
  # IPv4 bringt den Weg nach draussen (Paketquellen, GitHub) ueber NAT mit,
  # und das oeffentliche IPv4 kommt als zweite Schnittstelle dazu.
  primary_network_id = var.ip_mode == "ipv4" ? var.network_v4_uuid : var.network_v6_uuid

  dual = var.ip_mode == "dual"
}

# SSH je Adressfamilie. Die gemeinsame Security Group bleibt zusaetzlich
# dran; sie ist ausserhalb dieses Templates gepflegt und muss nicht fuer
# beide Familien Regeln haben.
resource "openstack_networking_secgroup_v2" "ssh" {
  name        = "${local.app_name}-ssh"
  description = "SSH zur gemeinsamen VM (${var.ip_mode})"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  for_each = toset(local.ethertypes)

  security_group_id = openstack_networking_secgroup_v2.ssh.id
  direction         = "ingress"
  ethertype         = each.key
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.key == "IPv4" ? "0.0.0.0/0" : "::/0"
  description       = "SSH (${each.key})"
}

# Zweite Schnittstelle fuer dual, vorab als Port angelegt: so sind MAC und
# Adresse schon bekannt, wenn cloud-init sein user-data bekommt.
resource "openstack_networking_port_v2" "v4" {
  count      = local.dual ? 1 : 0
  name       = "${local.app_name}-shared-v4"
  network_id = var.network_v4_uuid

  security_group_ids = [
    var.shared_secgroup_id,
    openstack_networking_secgroup_v2.ssh.id,
  ]
}

locals {
  secondary_ipv4 = local.dual ? [
    for ip in openstack_networking_port_v2.v4[0].all_fixed_ips : ip if length(regexall(":", ip)) == 0
  ][0] : ""
}

############################
# USER MANAGEMENT (CONTRACT)
############################

# Flatten users from teams - EXAKT wie im Contract vorgegeben
locals {
  # Team -> Linux-Gruppenname. Gruppen muessen mit einem Buchstaben beginnen,
  # daher das Praefix fuer Teams, die mit einer Ziffer anfangen.
  group_names = {
    for team in keys(var.users) : team => (
      can(regex("^[a-z]", trim(replace(lower(team), "/[^a-z0-9_-]+/", "-"), "-")))
      ? trim(replace(lower(team), "/[^a-z0-9_-]+/", "-"), "-")
      : "t-${trim(replace(lower(team), "/[^a-z0-9_-]+/", "-"), "-")}"
    )
  }

  all_users = flatten([
    for team, members in var.users : [
      for member in members : {
        id       = "${team}-${replace(split("@", member.email)[0], ".", "-")}"
        team     = team
        email    = member.email
        username = lower(replace(split("@", member.email)[0], ".", ""))

        # Linux-Gruppenname. "Team #1" ist als Gruppe unzulaessig (Grossbuchstabe,
        # Leerzeichen, '#'), deshalb auf [a-z0-9_-] herunterbrechen: "team-1".
        # Der huebsche Name bleibt in team/metadata/outputs erhalten.
        group = local.group_names[team]
      }
    ]
  ])

  # Eindeutige Teams extrahieren
  unique_teams = distinct([for user in local.all_users : user.team])

  # Dieselben Teams als Linux-Gruppennamen
  unique_groups = distinct([for user in local.all_users : user.group])

  # VM-Anzahl = 1 (eine gemeinsame VM)
  vm_count = 1

  # Liste aller Usernamen und E-Mails
  usernames = [for user in local.all_users : user.username]
  emails    = [for user in local.all_users : user.email]
  user_ids  = [for user in local.all_users : user.id]
}

# Passwörter für jeden User generieren
resource "random_password" "user_passwords" {
  count            = length(local.all_users)
  length           = 16
  special          = true
  override_special = "!@%^*_-+="
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

# Packer-built image lookup by name (keine IDs hardcoden)
data "openstack_images_image_v2" "image" {
  name        = var.image_name
  most_recent = true
}

# External network nur nötig, wenn Floating IP aktiviert ist
data "openstack_networking_network_v2" "external" {
  count = local.enable_floating_ip ? 1 : 0
  name  = var.floating_ip_pool
}

# -----------------------------------------------------------------------------
# Shared VM
# -----------------------------------------------------------------------------
resource "openstack_compute_instance_v2" "shared_vm" {
  name        = "${local.app_name}-shared"
  image_id    = data.openstack_images_image_v2.image.id
  flavor_name = local.flavor
  key_pair    = local.key_pair != "" ? local.key_pair : null

  security_groups = [var.shared_secgroup_id, openstack_networking_secgroup_v2.ssh.id]

  timeouts {
    create = "15m"
    delete = "15m"
  }

  # Nur die Hauptschnittstelle. Die zweite bei dual haengt
  # interface_attach unten an: als zweiter network-Block wuerde cloud-init
  # sie beim ersten Boot mit einer eigenen Default-Route einrichten, und
  # zwei Default-Routen in der Haupttabelle schicken Antworten ueber die
  # falsche Schnittstelle hinaus.
  network {
    uuid = local.primary_network_id
  }

  user_data = templatefile("${path.module}/cloud-init-multi-user.yml.tpl", {
    all_users      = local.all_users
    unique_teams   = local.unique_teams
    unique_groups  = local.unique_groups
    passwords      = [for p in random_password.user_passwords : p.result]
    secondary_mac  = local.dual ? openstack_networking_port_v2.v4[0].mac_address : ""
    secondary_ipv4 = local.secondary_ipv4
  })

  lifecycle {
    precondition {
      condition     = var.ip_mode == "ipv6" || var.network_v4_uuid != ""
      error_message = "ip_mode \"${var.ip_mode}\" braucht ein IPv4-Netz in network_v4_uuid."
    }
    precondition {
      condition     = var.ip_mode == "ipv4" || var.network_v6_uuid != ""
      error_message = "ip_mode \"${var.ip_mode}\" braucht ein IPv6-Netz in network_v6_uuid."
    }
  }

  metadata = merge(local.metadata, {
    teams  = join(",", local.unique_teams)
    users  = join(",", local.usernames)
    emails = join(",", local.emails)
  })
}

# Zweite Schnittstelle (dual) an die laufende Instanz. Eingerichtet wird sie
# von cloud-init, das auf ihre MAC wartet - siehe runcmd im Template.
resource "openstack_compute_interface_attach_v2" "v4" {
  count       = local.dual ? 1 : 0
  instance_id = openstack_compute_instance_v2.shared_vm.id
  port_id     = openstack_networking_port_v2.v4[0].id
}

locals {
  ipv4_address = (
    var.ip_mode == "ipv4" ? openstack_compute_instance_v2.shared_vm.network[0].fixed_ip_v4
    : local.dual ? local.secondary_ipv4
    : null
  )
  ipv6_address = var.ip_mode == "ipv4" ? null : openstack_compute_instance_v2.shared_vm.network[0].fixed_ip_v6

  # Verbindungsziel fuer die Zugangsdaten. Bei dual IPv4, weil es mehr
  # Heimnetze erreicht; die IPv6 steht in team_vms daneben.
  access_ip = try(coalesce(local.ipv4_address, local.ipv6_address), null)
}

# -----------------------------------------------------------------------------
# Optional Floating IP (eine für die gemeinsame VM)
# -----------------------------------------------------------------------------
resource "openstack_networking_floatingip_v2" "fip" {
  count = local.enable_floating_ip ? 1 : 0
  pool  = data.openstack_networking_network_v2.external[0].name
}

# Warten bis cloud-init die Benutzer angelegt hat. Ohne das meldet Terraform
# fertig, sobald die Instanz ACTIVE ist - die Zugangsdaten gehen dann raus,
# bevor der Login funktioniert.
resource "time_sleep" "wait_for_vm" {
  depends_on = [
    openstack_compute_instance_v2.shared_vm,
    openstack_compute_interface_attach_v2.v4,
  ]
  create_duration = "90s"
}

# Port-ID der VM finden
data "openstack_networking_port_v2" "vm_port" {
  count      = local.enable_floating_ip ? 1 : 0
  device_id  = openstack_compute_instance_v2.shared_vm.id
  network_id = local.primary_network_id
  depends_on = [
    openstack_compute_instance_v2.shared_vm,
    time_sleep.wait_for_vm
  ]
}

# Floating IP Association mit data-basierter Port-ID
resource "openstack_networking_floatingip_associate_v2" "fip_assoc" {
  count       = local.enable_floating_ip ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.fip[0].address
  port_id     = data.openstack_networking_port_v2.vm_port[0].id

  depends_on = [
    data.openstack_networking_port_v2.vm_port,
    time_sleep.wait_for_vm
  ]
}
