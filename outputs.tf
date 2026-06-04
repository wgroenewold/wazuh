output "dashboard_floating_ip" {
  description = "Publiek IP van de Wazuh dashboard node"
  value       = openstack_networking_floatingip_v2.dashboard.address
}

output "internal_ips" {
  description = "Interne IP-adressen van alle nodes"
  value = {
    for name, inst in openstack_compute_instance_v2.wazuh :
    name => openstack_networking_port_v2.wazuh[name].all_fixed_ips[0]
  }
}
