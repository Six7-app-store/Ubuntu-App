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