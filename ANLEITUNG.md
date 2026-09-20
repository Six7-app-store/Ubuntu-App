# App-Vorlage für OpenStack — Aufbau und Anleitung

Diese Dateien beschreiben eine App für den DHBW App Store. Sie sind auf
`newstack.dhbw.cloud`, Projekt `ma_wwi_24sea_appstore_g1` abgestimmt und dort
erprobt.

---

## 1. Was die Dateien tun

| Datei | Aufgabe |
|---|---|
| `packer/template.pkr.hcl` | Beschreibt, wie das Image gebaut wird: Basis-Image, Flavor, Netz |
| `packer/variables.pkr.hcl` | Die Stellschrauben des Builds |
| `packer/scripts/provision.sh` | **Was installiert wird** — hier steckt der Inhalt deiner App |
| `terraform/main.tf` | Erzeugt die VM aus dem gebauten Image |
| `terraform/variables.tf` | Netz, Security Group, Nutzerliste |
| `terraform/cloud-init-multi-user.yml.tpl` | **Was beim ersten Start passiert** — Konten, Verzeichnisse, Dienste |
| `terraform/outputs.tf` | Was der Studierende als Zugangsdaten zu sehen bekommt |

Die Kette dahinter:

```
Packer baut ein Image  →  Terraform erzeugt daraus eine VM
                       →  Terraform übergibt user_data
                       →  cloud-init richtet beim ersten Boot alles ein
```

**Terraform legt keine Nutzer an.** Es reicht nur einen Zettel (`user_data`) an
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
   `https://github.com/Six7-app-store/Ubuntu-App` mit Release `v1.1.1`.
3. **Freigeben** — über die Admin-Seite unter `/admin/apps`.
4. **Deployment starten** — der Assistent führt durch Konfiguration, Teams und
   Variablen.

Der Worker erledigt dann: Repo klonen → `packer build` → `terraform apply` →
Zugangsdaten je Studierendem ausgeben.

**Wichtig:** Das App-Repo hat bewusst keinen Deploy-Knopf. Die enthaltenen
GitHub-Workflows prüfen nur Formatierung und Syntax (`fmt`, `validate`,
`tflint`, `tfsec`) — sie fassen OpenStack nicht an, und sie enthalten keine
Zugangsdaten. Müsste jedes App-Repo selbst ausrollen können, bräuchte es die
Zugangsdaten jedes Kurses.

---

## 3. Weg B: Von Hand, zum Ausprobieren

Sinnvoll, um eine eigene App zu entwickeln, ohne jedes Mal den ganzen App Store
zu durchlaufen.

### Voraussetzungen

- `packer` und `terraform`
- Eine `clouds.yaml` unter `~/.config/openstack/clouds.yaml`
- Campusnetz oder VPN — die OpenStack-API ist von außen nicht erreichbar

```bash
export OS_CLOUD=openstack
```

Beide Werkzeuge lesen die Zugangsdaten über `cloud = "openstack"` aus dieser
Datei. Es müssen keine Passwörter in die Vorlagen.

### Schritt 1: Image bauen

```bash
cd packer
packer init .
packer build -var image_name=meine-app-v1 .
```

Dauert bei Linux etwa 10–15 Minuten. Am Ende liegt ein neues Image namens
`meine-app-v1` in OpenStack. Prüfen mit:

```bash
openstack image list --private
```

### Schritt 2: VM erzeugen

Lege eine Datei `terraform/meine.auto.tfvars` an:

```hcl
image_name = "meine-app-v1"

users = {
  "Team 1" = [
    { email = "vorname.nachname@dhbw.de" },
  ]
}
```

Der Name auf der Kommandozeile wäre schwer zu tippen, weil `users` eine
verschachtelte Struktur ist — deshalb die Datei.

```bash
cd ../terraform
terraform init
terraform plan      # zeigt, was entstehen würde, ändert nichts
terraform apply
```

### Schritt 3: Zugangsdaten auslesen

```bash
terraform output -json user_accounts
```

Darin stehen Benutzername, Passwort und die IPv6-Adresse. Verbinden:

```bash
ssh benutzername@2001:7c0:1b20:...
```

### Schritt 4: Wieder abräumen

```bash
terraform destroy
```

**Nicht vergessen** — eine vergessene VM verbraucht weiter Quota. Das gebaute
Image bleibt davon unberührt und muss separat gelöscht werden:

```bash
openstack image delete meine-app-v1
```

---

## 4. Eine eigene App daraus machen

Drei Stellen, mehr braucht es meistens nicht:

**`packer/scripts/provision.sh`** — was installiert wird. Ein normales
Shell-Skript, das beim Build in der VM läuft. Hier kommt deine Software hinein.

**`terraform/cloud-init-multi-user.yml.tpl`** — was beim ersten Start jeder VM
passiert: Konten anlegen, Dienste starten, Dateien schreiben.

**`terraform/outputs.tf`** — was der Studierende angezeigt bekommt. Der Block
`user_accounts` ist als `[CONTRACT]` markiert: Der App Store erwartet diese
Struktur, also die Felder beibehalten und nur die Werte anpassen.

Dazu in `terraform/main.tf` unter `locals` die App-Vorgaben:

```hcl
app_name = "ubuntu-user"   # Namenspräfix der VM
flavor   = "gp1.small"     # Größe
```

---

## 5. Stolpersteine, die uns tatsächlich passiert sind

**Basis-Image.** Die Vorlage suchte ursprünglich `Ubuntu 22.04`, das es auf
newstack nicht mehr gibt — der Build brach nach 327 Millisekunden ab. Jetzt ist
es die Variable `source_image_name` mit Default `Ubuntu 24.04`. Vorhanden sind
`Ubuntu 24.04` und `Ubuntu Server 26.04 LTS`.

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
`enable_floating_ip = false`.

**Der Image-Name muss übereinstimmen.** Was bei `packer build` als
`image_name` gesetzt wird, muss in Terraform dasselbe sein — sonst findet
Terraform das Image nicht.

**Build-Zeit.** Der App Store bricht einen Packer-Build nach **einer Stunde**
hart ab (`SIGKILL`). Linux-Images bleiben mit 10–15 Minuten weit darunter. Bei
großen Images wird es eng, und beim harten Abbruch bleibt Packers temporäre
Bau-VM in OpenStack liegen.
