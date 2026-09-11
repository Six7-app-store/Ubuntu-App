packer {
  required_plugins {
    openstack = {
      source  = "github.com/hashicorp/openstack"
      version = "~> 1"
    }
  }
}

source "openstack" "image" {
  cloud             = "openstack"
  image_name        = var.image_name
  source_image_name = var.source_image_name
  flavor            = "gp1.small"
  networks          = var.networks
  security_groups   = var.security_groups
  ssh_username      = "ubuntu"
}

build {
  sources = ["source.openstack.image"]

  provisioner "shell" {
    script = "scripts/provision.sh"
  }
}
