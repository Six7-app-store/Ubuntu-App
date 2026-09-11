variable "source_image_name" {
  type        = string
  description = "Basis-Image, auf dem gebaut wird @openstack:image:name"
  default     = "Ubuntu 24.04"
}

variable "image_name" {
  type        = string
  description = "Glance-Image-Name — vom Worker zur Build-Zeit gesetzt. @platform:internal"
  default     = "ubuntu-v1"
}

variable "networks" {
  type        = list(string)
  description = "@openstack:network:id:list Build-Netzwerke"
  default     = ["9b579624-d844-4df3-b38d-89978b31d37d"]
}

variable "security_groups" {
  type        = list(string)
  description = "@openstack:security_group:id:list Build-Security-Groups"
  default     = ["7ca4f889-e11e-4a16-83a8-73a77ebdbbe6"]
}
