# Prüft, wie Größe und Einrichtung der VM aus den Variablen entstehen.
# Alle Provider sind gemockt: der Test braucht keinen OpenStack-Zugang und
# legt nichts an.
#
#   cd tofu && tofu init -backend=false && tofu test

mock_provider "openstack" {
  mock_data "openstack_images_image_v2" {
    defaults = {
      id = "00000000-0000-0000-0000-00000000image"
    }
  }
  mock_resource "openstack_compute_instance_v2" {
    defaults = {
      network = { fixed_ip_v6 = "2001:db8::42", fixed_ip_v4 = "10.200.0.42" }
    }
  }
}

mock_provider "random" {}
mock_provider "time" {}

variables {
  users = {
    "Team #1" = [{ email = "Anna.Alt@dhbw.de" }]
    "2b"      = [{ email = "ben@dhbw.de" }, { email = "cem@dhbw.de" }]
  }
}

run "standardgroesse_ohne_volume" {
  command = apply

  assert {
    condition     = openstack_compute_instance_v2.shared_vm.flavor_name == "gp1.small"
    error_message = "Ohne Auswahl muss gp1.small gelten."
  }
  assert {
    condition     = length(openstack_compute_instance_v2.shared_vm.block_device) == 0
    error_message = "disk_size_gb = 0 darf kein Volume anlegen."
  }
  assert {
    condition     = openstack_compute_instance_v2.shared_vm.image_id == "00000000-0000-0000-0000-00000000image"
    error_message = "Ohne Volume bootet die VM direkt vom Image."
  }
}

run "gewaehlte_groesse_und_platte" {
  command = apply

  variables {
    flavor       = "gp1.large"
    disk_size_gb = 50
  }

  assert {
    condition     = openstack_compute_instance_v2.shared_vm.flavor_name == "gp1.large"
    error_message = "Der gewählte Flavor muss an der VM ankommen."
  }
  assert {
    condition     = length(openstack_compute_instance_v2.shared_vm.block_device) == 1
    error_message = "Eine Plattengröße muss genau ein Boot-Volume anlegen."
  }
  assert {
    condition     = openstack_compute_instance_v2.shared_vm.block_device[0].volume_size == 50
    error_message = "Das Volume muss die gewählte Größe haben."
  }
  assert {
    condition     = openstack_compute_instance_v2.shared_vm.block_device[0].delete_on_termination
    error_message = "Das Volume muss mit der VM verschwinden."
  }
  # image_id selbst lässt sich hier nicht prüfen: das Feld ist berechnet, und
  # der Mock füllt das null aus der Konfiguration mit einem Zufallswert.
  assert {
    condition     = local.boot_from_volume
    error_message = "Eine Plattengröße muss den Boot vom Volume auslösen."
  }
}

run "cloud_init_richtet_benutzer_und_kurs_ein" {
  command = apply

  assert {
    condition     = startswith(local.cloud_init, "#cloud-config\n")
    error_message = "user_data muss mit #cloud-config beginnen."
  }
  assert {
    condition     = toset([for u in yamldecode(local.cloud_init).users : u.name]) == toset(["annaalt", "ben", "cem"])
    error_message = "Jede Person bekommt einen Account, Name aus der E-Mail, klein und ohne Punkte."
  }
  assert {
    condition     = toset(yamldecode(local.cloud_init).groups) == toset(["team-1", "t-2b"])
    error_message = "Teamnamen müssen gültige Linux-Gruppen werden (\"Team #1\" -> team-1, \"2b\" -> t-2b)."
  }
  assert {
    condition     = length(yamldecode(local.cloud_init).chpasswd.users) == 3
    error_message = "Jede Person braucht ein Passwort."
  }
  assert {
    condition     = length([for f in yamldecode(local.cloud_init).write_files : f if startswith(f.path, "/etc/skel/linux-kurs/")]) == 9
    error_message = "Alle neun Dateien des Lernverzeichnisses gehören nach /etc/skel."
  }
  assert {
    condition     = strcontains(one([for f in yamldecode(local.cloud_init).write_files : f.content if endswith(f.path, "03-berechtigungen/aufgaben.txt")]), "echo \"Hallo, $(whoami)!\"")
    error_message = "Lerndateien müssen unverändert ankommen, auch mit $(...) darin."
  }
}

run "zugang_ueber_ipv6" {
  command = apply

  assert {
    condition     = alltrue([for a in values(output.user_accounts) : a.ip == "2001:db8::42"])
    error_message = "Im DHBWV6-Netz ist nur IPv6 öffentlich - die Zugangsdaten müssen sie nennen."
  }
}

run "unbekannter_flavor_wird_abgelehnt" {
  command = plan

  variables {
    flavor = "gpu.huge"
  }

  expect_failures = [var.flavor]
}

run "zu_kleine_platte_wird_abgelehnt" {
  command = plan

  variables {
    disk_size_gb = 5
  }

  expect_failures = [var.disk_size_gb]
}

run "zu_grosse_platte_wird_abgelehnt" {
  command = plan

  variables {
    disk_size_gb = 500
  }

  expect_failures = [var.disk_size_gb]
}
