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