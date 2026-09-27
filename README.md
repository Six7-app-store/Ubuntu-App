# Ubuntu Terminal App
 
Eine einfache Linux-Lernumgebung für Hochschulkurse. Jeder Studierende

bekommt einen eigenen SSH-Zugang auf einer gemeinsamen Ubuntu 26.04 VM

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
 
## User-Management
 
- **Ein Account pro Nutzer**, abgeleitet aus der E-Mail-Adresse

  (z.B. `alice.smith@dhbw.de` → Benutzername `alicesmith`)

- Alle Nutzer aller Teams landen auf **einer gemeinsamen VM**

- Jeder Nutzer erhält ein automatisch generiertes, zufälliges Passwort

- SSH-Login mit Passwort-Authentifizierung (kein Key nötig)
 
## VM-Deployment
 
| | |

|---|---|

| VMs gesamt | **1** (geteilt von allen Teams und Nutzern) |

| VMs pro Team | — |

| VMs pro Nutzer | — |

| Flavor | `gp1.small` |

| Floating IP | Nein (feste Adresse, siehe Adressfamilie) |
 
## Adressfamilie (`ip_mode`)

Das Template bietet die VM über IPv4, IPv6 oder beides an. Der Wizard zeigt
`ip_mode` als Auswahlliste.

| `ip_mode` | Schnittstellen | SSH-Regeln |
|---|---|---|
| `ipv4` | eine, im Netz `network_v4_uuid` (z. B. DHBWv4) | IPv4 |
| `ipv6` | eine, im Netz `network_v6_uuid` (z. B. DHBWV6) — Standard | IPv6 |
| `dual` | Haupt-Schnittstelle in `network_v6_uuid`, zweite in `network_v4_uuid` | IPv4 und IPv6 |

Security-Group-Regeln gelten je Adressfamilie: eine IPv4-Regel lässt kein
IPv6-Paket durch. Das Template legt deshalb für jede gewählte Familie eine
eigene SSH-Regel an.

Bei `dual` hängt Terraform die IPv4-Schnittstelle erst an die laufende VM,
und cloud-init richtet sie mit eigener Routing-Tabelle ein. Antworten von
der IPv4-Adresse müssen über deren eigenes Gateway hinaus, sonst verwirft
Neutrons Port-Security sie als gefälschten Absender. Dasselbe Muster nutzt
der Staging-Aufbau im `deployment`-Repo. Die Zugangsdaten nennen bei `dual`
die IPv4-Adresse, `team_vms` zeigt beide.

## Konfigurierbare Variablen
 
| Variable | Beschreibung | Pflicht |

|---|---|---|

| `ip_mode` | `ipv4`, `ipv6` oder `dual` | Nein (Standard `ipv6`) |

| `network_v4_uuid` | Netz mit öffentlich gerouteter IPv4 | Bei `ipv4` und `dual` |

| `network_v6_uuid` | Netz mit öffentlicher IPv6 | Bei `ipv6` und `dual` |

| `floating_ip_pool` | Name des External Networks für Floating IPs | Ja |

| `shared_secgroup_id` | ID der gemeinsamen Security Group | Ja |
 
## Deployment-Dauer
 
| Schritt | Dauer (ca.) |

|---|---|

| Packer Image Build | 10–15 min |

| Terraform apply | 3–5 min |

| **Gesamt (Erstdeployment)** | **13–20 min** |
 
Bei Folge-Deployments (Image bereits gebaut) nur Terraform: **3–5 min**.

 