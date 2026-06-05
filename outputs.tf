output "dashboard_floating_ip" {
  description = "Public IP of Wazuh dashboard"
  value       = openstack_networking_floatingip_v2.dashboard.address
}

output "salt_master_floating_ip" {
  description = "Public IP of the Salt master node"
  value       = openstack_networking_floatingip_v2.salt_master.address
}

output "internal_ips" {
  description = "Internal IP addresses of all nodes"
  value = {
    for name, inst in openstack_compute_instance_v2.wazuh :
    name => openstack_networking_port_v2.wazuh[name].all_fixed_ips[0]
  }
}
