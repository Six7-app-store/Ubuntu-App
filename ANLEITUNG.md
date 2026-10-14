# App-Vorlage für OpenStack — Aufbau und Anleitung

Diese Dateien beschreiben eine App für den DHBW App Store. Sie sind auf
`newstack.dhbw.cloud`, Projekt `ma_wwi_24sea_appstore_g1` abgestimmt und dort
erprobt.

---

## 1. Was die Dateien tun

| Datei | Aufgabe |
|---|---|
| `tofu/main.tofu` | Erzeugt die VM: Image, Größe, Netz, optional ein Boot-Volume |
| `tofu/variables.tofu` | Was im Wizard einstellbar ist: Größe, Platte, Netz, Security Group |
| `tofu/cloud-init.tofu` | **Was beim ersten Start passiert** — Pakete, Konten, Dateien, Dienste |
| `tofu/linux-kurs/` | Das Lernverzeichnis, das jeder Nutzer im Home-Ordner bekommt |
| `tofu/outputs.tofu` | Was der Studierende als Zugangsdaten zu sehen bekommt |
| `tofu/tests/` | `tofu test` mit gemockten Providern — prüft ohne OpenStack-Zugang |

Die VM wird mit **OpenTofu** (`tofu`) ausgerollt. Der App Store erwartet
genau einen Ordner `tofu/` mit `*.tofu`-Dateien; ein Repo mit `packer/` oder
`terraform/` lehnt er ab (ADR 0010 im deployment-Repo).

Die Kette dahinter:

```
OpenTofu erzeugt die VM aus dem Basis-Image "Ubuntu 24.04"
  →  OpenTofu übergibt user_data
  →  cloud-init richtet beim ersten Boot alles ein
```

Ein eigenes Image wird nicht mehr gebaut. Was früher Packer vorinstalliert
hat, installiert cloud-init jetzt bei jedem Start.

**OpenTofu legt keine Nutzer an.** Es reicht nur einen Zettel (`user_data`) an
die VM weiter. Wer ihn abarbeitet, ist cloud-init *innerhalb* der VM. Das ist
die wichtigste Stelle zum Verstehen — und der Grund, warum Windows-Images
zusätzlich `cloudbase-init` brauchen.

---

## 2. Weg A: Über den App Store (der vorgesehene Weg)

So rollen die Studierenden die App später aus. Du brauchst dafür **keine**
dieser Dateien lokal — nur ein Git-Repo, auf das der App Store zeigt.

1. **OpenStack-Zugangsdaten hinterlegen** — im App Store unter
   *OpenStack-Credentials* die eigene `clouds.yaml` hochladen. Ohne diesen
   Schritt passiert nichts, denn der Worker rollt im Projekt des jeweiligen
   Nutzers aus.
2. **App registrieren** — Git-URL und Release angeben, z. B.
   `https://github.com/Six7-app-store/Ubuntu-App` mit einem Release ab `v2.0.0`
   (frühere Releases haben noch `terraform/` und werden abgelehnt).
3. **Freigeben** — über die Admin-Seite unter `/admin/apps`.
4. **Deployment starten** — der Assistent führt durch Konfiguration, Teams und
   Variablen. Größe und Festplatte der VM sind dort wählbar.

Der Worker erledigt dann: Repo klonen → `tofu apply` → Zugangsdaten je
Studierendem ausgeben.

**Wichtig:** Das App-Repo hat bewusst keinen Deploy-Knopf. Der enthaltene
GitHub-Workflow prüft nur Formatierung, Syntax und das Verhalten mit
gemockten Providern (`fmt`, `validate`, `test`) — er fasst OpenStack nicht an
und enthält keine Zugangsdaten. Müsste jedes App-Repo selbst ausrollen
können, bräuchte es die Zugangsdaten jedes Kurses.

---

## 3. Weg B: Von Hand, zum Ausprobieren

Sinnvoll, um eine eigene App zu entwickeln, ohne jedes Mal den ganzen App Store
zu durchlaufen.

### Voraussetzungen

- `tofu` (OpenTofu ≥ 1.13, z. B. `winget install OpenTofu.Tofu`)
- Eine `clouds.yaml` unter `~/.config/openstack/clouds.yaml`
- Campusnetz oder VPN — die OpenStack-API ist von außen nicht erreichbar

```bash
export OS_CLOUD=openstack
```

OpenTofu liest die Zugangsdaten über `cloud = "openstack"` aus dieser Datei.
Es müssen keine Passwörter in die Vorlagen.

### Schritt 0: Ohne OpenStack prüfen

```bash
cd tofu
tofu init
tofu test      # gemockte Provider, legt nichts an
```

### Schritt 1: VM erzeugen

Lege eine Datei `tofu/meine.auto.tfvars` an:

```hcl
flavor       = "gp1.medium"
disk_size_gb = 20

users = {
  "Team 1" = [
    { email = "vorname.nachname@dhbw.de" },
  ]
}
```

Der Name auf der Kommandozeile wäre schwer zu tippen, weil `users` eine
verschachtelte Struktur ist — deshalb die Datei.

```bash
tofu plan      # zeigt, was entstehen würde, ändert nichts
tofu apply
```

### Schritt 2: Zugangsdaten auslesen

```bash
tofu output -json user_accounts
```

Darin stehen Benutzername, Passwort und die IPv6-Adresse. Verbinden:

```bash
ssh benutzername@2001:7c0:1b20:...
```

Die Einrichtung läuft nach dem Boot noch einige Minuten weiter; fertig ist
sie, sobald `/var/log/setup-complete.log` existiert.

### Schritt 3: Wieder abräumen

```bash
tofu destroy
```

**Nicht vergessen** — eine vergessene VM verbraucht weiter Quota. Ein
Boot-Volume (bei `disk_size_gb` > 0) verschwindet mit der VM.

---

## 4. Eine eigene App daraus machen

Drei Stellen, mehr braucht es meistens nicht:

**`tofu/cloud-init.tofu`** — was beim ersten Start jeder VM passiert:
Pakete (`packages`), Konten, Dateien (`write_files`), Befehle (`runcmd`).
Hier kommt deine Software hinein. Die Konfiguration wird mit `yamlencode`
gebaut; Werte müssen deshalb nicht von Hand gequotet werden.

**`tofu/outputs.tofu`** — was der Studierende angezeigt bekommt. Der Block
`user_accounts` ist als `[CONTRACT]` markiert: Der App Store erwartet diese
Struktur, also die Felder beibehalten und nur die Werte anpassen.

**`tofu/variables.tofu`** — was im Wizard wählbar ist. Ein
`validation`-Block bestimmt die Auswahl:

```hcl
validation {
  condition = contains(["gp1.small", "gp1.large"], var.flavor)   # nur diese im Wizard
}
validation {
  condition = var.disk_size_gb >= 0 && var.disk_size_gb <= 200    # min/max im Wizard
}
```

Dazu in `tofu/main.tofu` unter `locals` die App-Vorgaben:

```hcl
app_name   = "ubuntu-user"    # Namenspräfix der VM
image_name = "Ubuntu 24.04"   # Basis-Image
```

---

## 5. Stolpersteine, die uns tatsächlich passiert sind

**Basis-Image.** Die Vorlage suchte ursprünglich `Ubuntu 22.04`, das es auf
newstack nicht mehr gibt. Vorhanden sind `Ubuntu 24.04` und
`Ubuntu Server 26.04 LTS`; die App nutzt `Ubuntu 24.04`.

**Fest verdrahtete UUIDs.** Netz und Security Group standen als UUIDs der alten
Cloud in den Defaults. Korrigiert auf:

| Ressource | UUID |
|---|---|
| Netz `DHBWV6` | `9b579624-d844-4df3-b38d-89978b31d37d` |
| Security Group `default` | `7ca4f889-e11e-4a16-83a8-73a77ebdbbe6` |

**IPv4 ist nicht erreichbar.** Im `DHBWV6`-Netz bekommt die VM `10.200.x.x` —
eine private NAT-Adresse. Öffentlich ist nur IPv6. Die Ausgaben nannten früher
die IPv4, der SSH-Befehl zeigte also ins Leere, obwohl das Deployment
fehlerfrei durchlief. Jetzt `fixed_ip_v6`.

**Floating IPs helfen nicht.** Sie lassen sich anlegen, aber nicht zuweisen —
zwischen VM-Subnetz und externem Netz fehlt ein Router. Deshalb
`enable_floating_ip = false`. Öffentliches IPv4 kommt stattdessen über
`ip_mode = "ipv4"` oder `"dual"` und ein IPv4-Netz in `network_v4_uuid`
(siehe README, Abschnitt Adressfamilie).

**Teamnamen sind keine gültigen Gruppennamen.** „Team #1“ wäre als
Linux-Gruppe unzulässig und hätte unquotiert in YAML alle Teams zu „Team“
verschmolzen. `main.tofu` bildet Teams deshalb auf `[a-z0-9_-]` ab
(`team-1`, mit Präfix `t-` für Teams, die mit einer Ziffer beginnen).

**Passwort-Auth wird vom Image überstimmt.** Ubuntu-Cloud-Images bringen
`/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` mit
`PasswordAuthentication no` mit, und sshd nimmt den ersten gefundenen Wert.
Die eigene Einstellung heißt deshalb `01-click-n-deploy.conf`.
