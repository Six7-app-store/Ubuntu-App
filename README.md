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
| Erreichbar über | IPv6 im Netz `DHBWV6` (die IPv4 dort ist eine private NAT-Adresse) |
| Floating IP | Nein |

## Konfigurierbare Variablen

| Variable | Beschreibung | Standard |
|---|---|---|
| `flavor` | Größe der VM. Der Wizard zeigt nur die erlaubten Flavors, jeweils mit vCPU, RAM und Platte. | `gp1.small` |
| `disk_size_gb` | Festplatte in GB. `0` nutzt die Platte des Flavors; 10–200 legt die Systemplatte als Volume dieser Größe an, das mit der VM gelöscht wird. | `0` |
| `network_uuid` | UUID des Netzwerks | `DHBWV6` |
| `floating_ip_pool` | Name des External Networks für Floating IPs (derzeit ungenutzt) | `DHBW` |
| `shared_secgroup_id` | ID der gemeinsamen Security Group | `default` |

Welche Größen wählbar sind, steht im `validation`-Block der Variablen in
[`tofu/variables.tofu`](tofu/variables.tofu); der App Store liest ihn aus
und baut daraus die Auswahl im Wizard.

## Einrichtung beim Boot

Es wird kein Image mehr gebaut (ADR 0010 im deployment-Repo): cloud-init
installiert die Software beim ersten Boot. Der SSH-Login geht, sobald die
Benutzer angelegt sind; Node.js und die übrigen Pakete kommen in den Minuten
danach dazu. Fertig ist die VM, sobald `/var/log/setup-complete.log` existiert.

Aufbau, Ausprobieren von Hand und Stolpersteine: [ANLEITUNG.md](ANLEITUNG.md).
