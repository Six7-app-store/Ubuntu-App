#cloud-config

# SSH mit Passwort-Auth aktivieren
ssh_pwauth: true

# Pakete installieren
packages:
  - curl
  - wget
  - git
  - htop
  - nano
  - vim
  - openssl
  - net-tools

# Gruppen für jedes Team erstellen.
# jsonencode() setzt jeden Wert in Anfuehrungszeichen: ohne das wuerde YAML
# "Team #1" am Leerzeichen-# abschneiden und alle Teams zu "Team" verschmelzen.
groups:
%{ for group in unique_groups ~}
  - ${jsonencode(group)}
%{ endfor ~}

# Benutzer erstellen
users:
%{ for idx, user in all_users ~}
  - name: ${jsonencode(user.username)}
    shell: /bin/bash
    sudo: ['ALL=(ALL) ALL']
    groups: ${jsonencode(user.group)}
    lock_passwd: false
%{ endfor ~}

# SSH-Konfiguration in separate Datei
write_files:
  - path: /etc/ssh/sshd_config.d/99-custom.conf
    content: |
      PasswordAuthentication yes
      PubkeyAuthentication yes
      PermitRootLogin no
      UsePAM yes
    permissions: '0644'
%{ if secondary_mac != "" ~}

  # ip_mode = dual: die IPv4-Schnittstelle, die Terraform nach dem Boot
  # anhaengt. Ihre DHCP-Routen gehen in eine eigene Tabelle, und nur
  # Pakete mit ihrer Adresse als Absender nehmen diese Tabelle. Ohne das
  # gingen Antworten ueber die Default-Route der Hauptschnittstelle hinaus,
  # und Neutrons Port-Security verwirft sie als gefaelschten Absender.
  - path: /etc/netplan/60-secondary-ipv4.yaml
    permissions: '0600'
    content: |
      network:
        version: 2
        ethernets:
          secondary:
            match:
              macaddress: "${secondary_mac}"
            dhcp4: true
            dhcp6: false
            accept-ra: false
            dhcp4-overrides:
              route-table: 100
            routing-policy:
              - from: "${secondary_ipv4}"
                table: 100
%{ endif ~}

# Setup-Befehle
# Passwoerter zwingend ueber jsonencode(): ein Passwort, das mit ! @ % oder *
# beginnt, ist als unquotierter YAML-Skalar ein Syntaxfehler und liesse das
# komplette user-data scheitern - die VM liefe dann ganz ohne Benutzer.
chpasswd:
  expire: false
  users:
%{ for idx, user in all_users ~}
    - name: ${jsonencode(user.username)}
      password: ${jsonencode(passwords[idx])}
      type: text
%{ endfor ~}

runcmd:
  - systemctl restart ssh
%{ if secondary_mac != "" ~}

  # Die IPv4-Schnittstelle kommt erst nach dem Boot dazu (interface_attach).
  # Bis zu fuenf Minuten auf ihre MAC warten, dann die netplan-Datei oben
  # anwenden. Kommt sie nicht, bleibt die VM ueber IPv6 erreichbar.
  - |
    for i in $(seq 1 60); do
      if ip -o link | grep -qi "${secondary_mac}"; then
        netplan apply
        break
      fi
      sleep 5
    done
%{ endif ~}

  # Firewall: erst SSH freigeben, dann einschalten (nicht umgekehrt)
  - ufw allow OpenSSH
  - ufw --force enable
  
  # Setup-Log (OHNE Passwörter aus Sicherheitsgründen)
  - |
    cat >> /var/log/setup-complete.log <<EOF
    ================================================
    Setup abgeschlossen: $(date)
    ================================================
    Teams: ${join(", ", unique_teams)}
    Benutzer erstellt: ${length(all_users)}
    ================================================
    EOF

# Abschlussnachricht
final_message: |
  ================================================
  Ubuntu Multi-User System bereit!
  ================================================
  Teams: ${join(", ", unique_teams)}
  Benutzer: ${length(all_users)}
  
  SSH-Login: ssh <username>@<vm-ip>
  ================================================