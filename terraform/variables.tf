################################################
# PFLICHT-Variablen
################################################

variable "users" {
  description = "Per-team roster — vom Worker injiziert. @platform:internal"
  type = map(list(object({
    email = string
  })))
  default = {}
}

variable "image_name" {
  description = "Glance-Image-Name — vom Worker zur Apply-Zeit gesetzt. @platform:internal"
  type        = string
}

################################################
# Konfigurierbare Variablen
################################################

# Welche Adressfamilie die Instanz nach aussen anbietet. Waehlt das Netz und
# legt die Security-Group-Regeln an - je Familie eine eigene Regel, denn eine
# IPv4-Regel laesst kein einziges IPv6-Paket durch und umgekehrt.
#
#   ipv4  eine Schnittstelle im IPv4-Netz (network_v4_uuid)
#   ipv6  eine Schnittstelle im IPv6-Netz (network_v6_uuid)
#   dual  IPv6-Netz als Hauptschnittstelle, dazu eine zweite im IPv4-Netz
variable "ip_mode" {
  description = "Adressfamilie: ipv4, ipv6 oder dual (beide)"
  type        = string
  default     = "ipv6"

  validation {
    condition     = contains(["ipv4", "ipv6", "dual"], var.ip_mode)
    error_message = "ip_mode muss \"ipv4\", \"ipv6\" oder \"dual\" sein."
  }
}

variable "network_v4_uuid" {
  description = "Netz mit oeffentlich gerouteter IPv4, z. B. DHBWv4 - fuer ipv4 und dual @openstack:network:id"
  type        = string
  default     = ""
}

variable "network_v6_uuid" {
  description = "Netz mit oeffentlicher IPv6, z. B. DHBWV6 - fuer ipv6 und dual @openstack:network:id"
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