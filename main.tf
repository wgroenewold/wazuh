terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.0"
    }
  }
}

# Provider config via OS_* environment variables (clouds.yaml / openrc)
provider "openstack" {}

# ── Network ──────────────────────────────────────────────────────────────────

resource "openstack_networking_network_v2" "wazuh" {
  name           = var.network_name
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "wazuh" {
  name            = "${var.network_name}-subnet"
  network_id      = openstack_networking_network_v2.wazuh.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "wazuh" {
  name                = "${var.network_name}-router"
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "wazuh" {
  router_id = openstack_networking_router_v2.wazuh.id
  subnet_id = openstack_networking_subnet_v2.wazuh.id
}

data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

# ── Security Groups ───────────────────────────────────────────────────────────

resource "openstack_networking_secgroup_v2" "wazuh_internal" {
  name        = "wazuh-internal"
  description = "Allow all traffic within the Wazuh cluster"
}

resource "openstack_networking_secgroup_rule_v2" "internal_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.wazuh_internal.id
  security_group_id = openstack_networking_secgroup_v2.wazuh_internal.id
}

resource "openstack_networking_secgroup_v2" "wazuh_dashboard" {
  name        = "wazuh-dashboard"
  description = "External access to Wazuh dashboard"
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = var.allowed_cidr
  security_group_id = openstack_networking_secgroup_v2.wazuh_dashboard.id
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_cidr
  security_group_id = openstack_networking_secgroup_v2.wazuh_dashboard.id
}

# ── Instances ─────────────────────────────────────────────────────────────────

locals {
  nodes = {
    indexer   = { fixed_ip = var.ip_indexer,   secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id] }
    server    = { fixed_ip = var.ip_server,    secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id] }
    dashboard = { fixed_ip = var.ip_dashboard, secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id, openstack_networking_secgroup_v2.wazuh_dashboard.id] }
    client    = { fixed_ip = var.ip_client,    secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id] }
    client2   = { fixed_ip = var.ip_client2,   secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id] }
  }
}

resource "openstack_networking_port_v2" "wazuh" {
  for_each           = local.nodes
  name               = "wazuh-${each.key}"
  network_id         = openstack_networking_network_v2.wazuh.id
  security_group_ids = each.value.secgroups

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.wazuh.id
    ip_address = each.value.fixed_ip
  }
}

resource "openstack_compute_instance_v2" "wazuh" {
  for_each  = local.nodes
  name      = each.key
  flavor_id = data.openstack_compute_flavor_v2.wazuh.id
  image_id  = var.image_id
  key_pair  = var.key_pair

  network {
    port = openstack_networking_port_v2.wazuh[each.key].id
  }

  metadata = {
    role = each.key
  }
}

data "openstack_compute_flavor_v2" "wazuh" {
  name = var.flavor_name
}

# ── Floating IP (dashboard only) ─────────────────────────────────────────────

resource "openstack_networking_floatingip_v2" "dashboard" {
  pool = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "dashboard" {
  floating_ip = openstack_networking_floatingip_v2.dashboard.address
  port_id     = openstack_networking_port_v2.wazuh["dashboard"].id
}
