# -----------------------------------------------------------------------------
# Einrichtung der VM beim ersten Boot
#
# Ersetzt das frühere Packer-Image (ADR 0010 im deployment-Repo): was Packer
# vorinstalliert hat, installiert cloud-init jetzt bei jedem Start.
#
# Die Konfiguration wird mit yamlencode gebaut statt als Template. yamlencode
# quotet jeden Wert selbst: "Team #1" wird nicht am " #" abgeschnitten, ein
# Passwort mit führendem ! @ % oder * bleibt gültiges YAML, und Inhalte der
# Lerndateien wie "$(whoami)" kommen unverändert an.
# -----------------------------------------------------------------------------

locals {
  node_major = 24

  # Das Lernverzeichnis liegt unter tofu/linux-kurs/. write_files läuft vor
  # dem Anlegen der Benutzer, /etc/skel ist also schon gefüllt, wenn ihre
  # Home-Ordner entstehen.
  kurs_files = [
    for f in sort(fileset("${path.module}/linux-kurs", "**")) : {
      path        = "/etc/skel/linux-kurs/${f}"
      content     = file("${path.module}/linux-kurs/${f}")
      permissions = "0644"
    }
  ]

  cloud_init_config = {
    ssh_pwauth     = true
    package_update = true

    packages = [
      "ca-certificates",
      "curl",
      "git",
      "gnupg",
      "htop",
      "nano",
      "net-tools",
      "openssl",
      "python3",
      "python3-pip",
      "python3-venv",
      "tree",
      "vim",
      "wget",
    ]

    # Linux-Gruppen je Team (Namen aus local.group_names in main.tofu)
    groups = local.unique_groups

    users = [
      for user in local.all_users : {
        name        = user.username
        shell       = "/bin/bash"
        sudo        = ["ALL=(ALL) ALL"]
        groups      = user.group
        lock_passwd = false
      }
    ]

    write_files = concat(
      [
        {
          # Vorne einsortiert, damit es vor 60-cloudimg-settings.conf des
          # Ubuntu-Images gilt: sshd nimmt den ersten Wert.
          path        = "/etc/ssh/sshd_config.d/01-click-n-deploy.conf"
          permissions = "0644"
          content     = <<-EOT
            PasswordAuthentication yes
            PubkeyAuthentication yes
            PermitRootLogin no
            UsePAM yes
          EOT
        },
      ],
      local.kurs_files,
      # ip_mode = dual: die IPv4-Schnittstelle, die OpenTofu nach dem Boot
      # anhaengt. Ihre DHCP-Routen gehen in eine eigene Tabelle, und nur
      # Pakete mit ihrer Adresse als Absender nehmen diese Tabelle. Ohne das
      # gingen Antworten ueber die Default-Route der Hauptschnittstelle
      # hinaus, und Neutrons Port-Security verwirft sie als gefaelschten
      # Absender. Gleiches Muster wie der Staging-Aufbau im deployment-Repo.
      local.dual ? [
        {
          path        = "/etc/netplan/60-secondary-ipv4.yaml"
          permissions = "0600"
          content = yamlencode({
            network = {
              version = 2
              ethernets = {
                secondary = {
                  match           = { macaddress = local.secondary_mac }
                  dhcp4           = true
                  dhcp6           = false
                  accept-ra       = false
                  dhcp4-overrides = { route-table = 100 }
                  routing-policy  = [{ from = local.secondary_ipv4, table = 100 }]
                }
              }
            }
          })
        },
      ] : [],
    )

    chpasswd = {
      expire = false
      users = [
        for idx, user in local.all_users : {
          name     = user.username
          password = random_password.user_passwords[idx].result
          type     = "text"
        }
      ]
    }

    runcmd = concat([
      # Node.js aus dem NodeSource-Repository
      "mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --batch --yes --dearmor -o /etc/apt/keyrings/nodesource.gpg",
      "printf 'Types: deb\\nURIs: https://deb.nodesource.com/node_${local.node_major}.x/\\nSuites: nodistro\\nComponents: main\\nSigned-By: /etc/apt/keyrings/nodesource.gpg\\n' > /etc/apt/sources.list.d/nodesource.sources",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs",

      "systemctl restart ssh",
      ], local.dual ? [
      # Die IPv4-Schnittstelle kommt erst nach dem Boot dazu
      # (interface_attach). Bis zu fuenf Minuten auf ihre MAC warten, dann
      # die netplan-Datei oben anwenden. Kommt sie nicht, bleibt die VM
      # ueber IPv6 erreichbar.
      ["sh", "-c", "for i in $(seq 1 60); do if ip -o link | grep -qi \"$1\"; then netplan apply; break; fi; sleep 5; done", "sh", local.secondary_mac],
      ] : [], [

      # Firewall: erst SSH freigeben, dann einschalten (nicht umgekehrt)
      "ufw allow OpenSSH",
      "ufw --force enable",

      # Setup-Log (OHNE Passwörter aus Sicherheitsgründen). Teamnamen gehen
      # als Argument hinein, nicht in den Formatstring.
      ["sh", "-c", "printf 'Setup abgeschlossen: %s\\nTeams: %s\\nBenutzer erstellt: %s\\n' \"$(date)\" \"$1\" \"$2\" >> /var/log/setup-complete.log", "sh", join(", ", local.unique_teams), tostring(length(local.all_users))],
    ])

    final_message = <<-EOT
      ================================================
      Ubuntu Multi-User System bereit!
      ================================================
      Teams: ${join(", ", local.unique_teams)}
      Benutzer: ${length(local.all_users)}

      SSH-Login: ssh <username>@<vm-ip>
      ================================================
    EOT
  }

  cloud_init = "#cloud-config\n${yamlencode(local.cloud_init_config)}"
}
