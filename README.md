# Ubuntu Terminal App

Eine einfache Linux-Lernumgebung für Hochschulkurse. Jeder Studierende
bekommt einen eigenen SSH-Zugang auf einer gemeinsamen Ubuntu 24.04 VM
und ein vorgefertigtes Lernverzeichnis mit Übungsaufgaben und Kurzreferenz
zu den wichtigsten Terminal-Befehlen.

## Vorinstallierte Software

- Python 3 (inkl. pip, venv)
- Node.js 24 (inkl. npm)
- Git, curl, tree, nano, vim, htop

## Lernverzeichnis

Jeder Nutzer findet nach dem Login unter `~/linux-kurs/` folgende Struktur vor:

    ~/linux-kurs/
    ├── LIES_MICH.txt              ← Kurzreferenz aller wichtigen Befehle
    ├── beispieldaten/
    │   ├── studenten.csv          ← CSV für Übungen mit cut, grep, sort
    │   └── server.log             ← Logdatei für Übungen mit grep, tail, wc
    └── uebungen/
        ├── 01-navigation/
        ├── 02-dateien/
        ├── 03-berechtigungen/
        ├── 04-prozesse/
        └── 05-textverarbeitung/

Die Dateien liegen unter [`tofu/linux-kurs/`](tofu/linux-kurs/) und werden
beim ersten Boot nach `/etc/skel/linux-kurs/` geschrieben, bevor die
Benutzer angelegt werden.

## User-Management

- **Ein Account pro Nutzer**, abgeleitet aus der E-Mail-Adresse
  (z. B. `alice.smith@dhbw.de` → Benutzername `alicesmith`)
- Alle Nutzer aller Teams landen auf **einer gemeinsamen VM**, jedes Team
  als eigene Linux-Gruppe
- Jeder Nutzer erhält ein automatisch generiertes, zufälliges Passwort
- SSH-Login mit Passwort-Authentifizierung (kein Key nötig)

## VM-Deployment

| | |
|---|---|
| VMs gesamt | **1** (geteilt von allen Teams und Nutzern) |
| Größe | wählbar: `gp1.small`, `gp1.medium`, `gp1.large` (Standard `gp1.small`) |
| Festplatte | wählbar: 10–200 GB, Standard ist die Platte des Flavors (10 GB) |
| Erreichbar über | wählbar: IPv6 (Standard), IPv4 oder beides — siehe [Adressfamilie](#adressfamilie-ip_mode) |
| Floating IP | Nein |

## Konfigurierbare Variablen

| Variable | Beschreibung | Standard |
|---|---|---|
| `flavor` | Größe der VM. Der Wizard zeigt nur die erlaubten Flavors, jeweils mit vCPU, RAM und Platte. | `gp1.small` |
| `disk_size_gb` | Festplatte in GB. `0` nutzt die Platte des Flavors; 10–200 legt die Systemplatte als Volume dieser Größe an, das mit der VM gelöscht wird. | `0` |
| `ip_mode` | Adressfamilie: `ipv4`, `ipv6` oder `dual` | `ipv6` |
| `network_uuid` | Netz mit öffentlicher IPv6, für `ipv6` und `dual` | `DHBWV6` |
| `network_v4_uuid` | Netz mit öffentlich gerouteter IPv4 (z. B. `DHBWv4`), für `ipv4` und `dual` | leer |
| `floating_ip_pool` | Name des External Networks für Floating IPs (derzeit ungenutzt) | `DHBW` |
| `shared_secgroup_id` | ID der gemeinsamen Security Group | `default` |

Welche Größen wählbar sind, steht im `validation`-Block der Variablen in
[`tofu/variables.tofu`](tofu/variables.tofu); der App Store liest ihn aus
und baut daraus die Auswahl im Wizard.

## Adressfamilie (`ip_mode`)

| `ip_mode` | Schnittstellen | SSH-Regeln | Zugangsdaten nennen |
|---|---|---|---|
| `ipv6` (Standard) | eine, im Netz `network_uuid` | IPv6 | die IPv6 |
| `ipv4` | eine, im Netz `network_v4_uuid` | IPv4 | die IPv4 |
| `dual` | Hauptschnittstelle in `network_uuid`, zweite in `network_v4_uuid` | beide | die IPv4; `team_vms` zeigt beide |

Die IPv4 im Netz `DHBWV6` ist eine private NAT-Adresse und taugt nicht als
Ziel. Öffentliches IPv4 gibt es nur über ein eigenes IPv4-Netz, deshalb
brauchen `ipv4` und `dual` die Variable `network_v4_uuid`; ohne sie bricht der
Plan mit einer klaren Meldung ab.

Security-Group-Regeln gelten je Adressfamilie: eine IPv4-Regel lässt kein
IPv6-Paket durch. Das Template legt deshalb eine eigene Gruppe mit einer
SSH-Regel je gewählter Familie an.

Bei `dual` hängt OpenTofu die IPv4-Schnittstelle erst an die laufende VM, und
cloud-init richtet sie mit eigener Routing-Tabelle ein. Antworten von der
IPv4-Adresse müssen über deren eigenes Gateway hinaus, sonst verwirft
Neutrons Port-Security sie als gefälschten Absender. Dasselbe Muster nutzt
der Staging-Aufbau im `deployment`-Repo.

Nicht gegen OpenStack geprüft ist, ob ein normales Nutzerprojekt auf
newstack Ports in einem öffentlichen IPv4-Netz anlegen darf. Für das Netz
`DHBW` verweigert Neutron das dem Staging-Projekt (403).

## Einrichtung beim Boot

Es wird kein Image mehr gebaut (ADR 0010 im deployment-Repo): cloud-init
installiert die Software beim ersten Boot. Der SSH-Login geht, sobald die
Benutzer angelegt sind; Node.js und die übrigen Pakete kommen in den Minuten
danach dazu. Fertig ist die VM, sobald `/var/log/setup-complete.log` existiert.

Aufbau, Ausprobieren von Hand und Stolpersteine: [ANLEITUNG.md](ANLEITUNG.md).
