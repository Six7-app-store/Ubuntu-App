
############################
# [CONTRACT] User Accounts Output
############################

output "user_accounts" {
  description = "[CONTRACT] User accounts mit Login-Informationen"
  sensitive   = true # Enthält Passwörter
  value = length(local.all_users) > 0 ? {
    for i in range(length(local.all_users)) : local.user_ids[i] => {
      type     = "password"
      ip       = local.enable_floating_ip ? openstack_networking_floatingip_v2.fip[0].address : openstack_compute_instance_v2.shared_vm.network[0].fixed_ip_v6
      port     = 22
      username = local.usernames[i]
      auth     = random_password.user_passwords[i].result
      email    = local.emails[i]
      team     = local.all_users[i].team
    }
  } : {}
}

############################
# VM Details
############################

output "team_vms" {
  description = "Details der gemeinsamen VM und aller Benutzer"
  value = local.vm_count > 0 ? {
    shared_vm = {
      instance_id   = openstack_compute_instance_v2.shared_vm.id
      instance_name = openstack_compute_instance_v2.shared_vm.name
      fixed_ip_v6   = openstack_compute_instance_v2.shared_vm.network[0].fixed_ip_v6
      floating_ip   = local.enable_floating_ip ? openstack_networking_floatingip_v2.fip[0].address : null
      users = [for i in range(length(local.all_users)) : {
        username    = local.usernames[i]
        team        = local.all_users[i].team
        ssh_command = local.enable_floating_ip ? "ssh ${local.usernames[i]}@${openstack_networking_floatingip_v2.fip[0].address}" : "ssh ${local.usernames[i]}@${openstack_compute_instance_v2.shared_vm.network[0].fixed_ip_v6}"
      }]
    }
  } : {}
}

output "teams_summary" {
  description = "Übersicht: Anzahl VMs und User"
  value = {
    vm_count   = local.vm_count
    user_count = length(local.all_users)
    usernames  = local.usernames
    emails     = local.emails
    teams      = local.unique_teams
  }
}

