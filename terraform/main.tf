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
  # Oeffentlich erreichbar ist die Instanz ueber IPv6; die feste IPv4
  # im DHBWV6-Netz ist eine private NAT-Adresse (10.200.x.x). Deshalb
  # geben die outputs fixed_ip_v6 als Verbindungsziel aus.
  enable_floating_ip = false

  metadata = {}
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

  security_groups = [var.shared_secgroup_id]

  timeouts {
    create = "15m"
    delete = "15m"
  }

  network {
    uuid = var.network_uuid
  }

  user_data = templatefile("${path.module}/cloud-init-multi-user.yml.tpl", {
    all_users     = local.all_users
    unique_teams  = local.unique_teams
    unique_groups = local.unique_groups
    passwords     = [for p in random_password.user_passwords : p.result]
  })

  metadata = merge(local.metadata, {
    teams  = join(",", local.unique_teams)
    users  = join(",", local.usernames)
    emails = join(",", local.emails)
  })
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
  depends_on      = [openstack_compute_instance_v2.shared_vm]
  create_duration = "90s"
}

# Port-ID der VM finden
data "openstack_networking_port_v2" "vm_port" {
  count     = local.enable_floating_ip ? 1 : 0
  device_id = openstack_compute_instance_v2.shared_vm.id
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
