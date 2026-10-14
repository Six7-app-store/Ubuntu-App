################################################
# Von der Plattform gesetzt
################################################

variable "users" {
  description = "Per-team roster — vom Worker injiziert."
  type = map(list(object({
    email = string
  })))
  default = {}
}

################################################
# Größe der VM
################################################

# Der Wizard zeigt nur diese Flavors, jeweils mit vCPU, RAM und Systemplatte
# aus OpenStack. Reihenfolge = Reihenfolge im Wizard, klein nach groß.
variable "flavor" {
  description = "Größe der VM (CPU und Arbeitsspeicher) @openstack:flavor"
  type        = string
  default     = "gp1.small"

  validation {
    condition     = contains(["gp1.small", "gp1.medium", "gp1.large"], var.flavor)
    error_message = "flavor muss gp1.small, gp1.medium oder gp1.large sein."
  }
}

# 0 = die Systemplatte des Flavors (bei gp1 10 GB), ohne Cinder. Jeder andere
# Wert legt die Systemplatte als Cinder-Volume dieser Größe an; es wird mit
# der VM gelöscht.
variable "disk_size_gb" {
  description = "Festplatte in GB (0 = Standardgröße des Flavors)"
  type        = number
  default     = 0

  validation {
    condition     = var.disk_size_gb >= 0 && var.disk_size_gb <= 200
    error_message = "disk_size_gb muss zwischen 0 und 200 liegen."
  }

  # Das Ubuntu-Image braucht mindestens 10 GB. Bewusst als eigener Block mit
  # ">": so liest der Wizard nur den Bereich 0–200 oben als Grenzen.
  validation {
    condition     = var.disk_size_gb == 0 || var.disk_size_gb > 9
    error_message = "disk_size_gb muss 0 oder mindestens 10 sein."
  }
}

################################################
# Netz
################################################

variable "network_uuid" {
  description = "Hauptnetzwerk @openstack:network:id"
  type        = string
  default     = "9b579624-d844-4df3-b38d-89978b31d37d"
}

variable "floating_ip_pool" {
  description = "Name des External Networks für Floating IPs @openstack:floating_ip_pool:name"
  type        = string
  default     = "DHBW"
}

variable "shared_secgroup_id" {
  description = "ID der gemeinsamen Security Group für alle VMs @openstack:security_group:id"
  type        = string
  default     = "7ca4f889-e11e-4a16-83a8-73a77ebdbbe6"
}
