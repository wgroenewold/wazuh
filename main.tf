terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

resource "openstack_networking_secgroup_v2" "wazuh_external" {
  name        = "wazuh-external"
  description = "External access to Wazuh cluster"
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = var.allowed_cidr
  security_group_id = openstack_networking_secgroup_v2.wazuh_external.id
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_cidr
  security_group_id = openstack_networking_secgroup_v2.wazuh_external.id
}

# ── Instances ─────────────────────────────────────────────────────────────────

locals {
  nodes = {
    indexer     = { fixed_ip = var.ip_indexer, secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id] }
    server      = { fixed_ip = var.ip_server, secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id] }
    dashboard   = { fixed_ip = var.ip_dashboard, secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id, openstack_networking_secgroup_v2.wazuh_external.id] }
    client      = { fixed_ip = var.ip_client, secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id] }
    client2     = { fixed_ip = var.ip_client2, secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id] }
    build       = { fixed_ip = var.ip_build, secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id] }
    salt-master = { fixed_ip = var.ip_salt_master, secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id, openstack_networking_secgroup_v2.wazuh_external.id] }
    wazuh5 = { fixed_ip = var.ip_wazuh5, secgroups = [openstack_networking_secgroup_v2.wazuh_internal.id, openstack_networking_secgroup_v2.wazuh_external.id] }
  }

  # Stripped-down map for use in templatefile() — only strings, no objects
  node_ips = {
    for name, node in local.nodes : name => node.fixed_ip
  }

  # All nodes except the salt-master get a minion keypair
  minion_nodes = {
    for name, node in local.nodes : name => node
    if name != "salt-master"
  }
}

resource "tls_private_key" "minion" {
  for_each  = local.minion_nodes
  algorithm = "RSA"
  rsa_bits  = 2048
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
  flavor_id = each.key == "build" ? data.openstack_compute_flavor_v2.build.id : each.key == "wazuh5" ? data.openstack_compute_flavor_v2.wazuh5.id : data.openstack_compute_flavor_v2.wazuh.id
  image_id  = data.openstack_images_image_v2.wazuh.id
  key_pair  = var.key_pair

  user_data = each.key == "salt-master" ? templatefile("${path.module}/cloud-init/master.yaml.tftpl", {
    node_ips        = local.node_ips
    internal_domain = var.internal_domain
    repository      = var.repository
    minion_count    = length(tls_private_key.minion)
    minion_pub_keys = {
      for name, key in tls_private_key.minion :
      "${name}.${var.internal_domain}" => indent(6, key.public_key_pem)
    }
    }) : each.key == "build" ? templatefile("${path.module}/cloud-init/build.yaml.tftpl", {
    master_ip       = var.ip_salt_master
    node_name       = each.key
    node_ips        = local.node_ips
    internal_domain = var.internal_domain
    minion_priv_key = indent(6, tls_private_key.minion[each.key].private_key_pem)
    minion_pub_key  = indent(6, tls_private_key.minion[each.key].public_key_pem)
    }) : templatefile("${path.module}/cloud-init/minion.yaml.tftpl", {
    master_ip       = var.ip_salt_master
    node_name       = each.key
    node_ips        = local.node_ips
    internal_domain = var.internal_domain
    minion_priv_key = indent(6, tls_private_key.minion[each.key].private_key_pem)
    minion_pub_key  = indent(6, tls_private_key.minion[each.key].public_key_pem)
  })

  network {
    port = openstack_networking_port_v2.wazuh[each.key].id
  }

  metadata = {
    role = each.key
  }
}

resource "openstack_blockstorage_volume_v3" "build" {
  name = "wazuh-build-repo"
  size = var.build_volume_size
}

resource "openstack_compute_volume_attach_v2" "build" {
  instance_id = openstack_compute_instance_v2.wazuh["build"].id
  volume_id   = openstack_blockstorage_volume_v3.build.id
}

data "openstack_compute_flavor_v2" "wazuh" {
  name = var.flavor_name
}

data "openstack_compute_flavor_v2" "build" {
  name = var.build_flavor_name
}

data "openstack_images_image_v2" "wazuh" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "wazuh5" {
  name = var.wazuh5_flavor_name
}

# ── Floating IPs ─────────────────────────────────────────────────────────────

resource "openstack_networking_floatingip_v2" "dashboard" {
  pool = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "dashboard" {
  floating_ip = openstack_networking_floatingip_v2.dashboard.address
  port_id     = openstack_networking_port_v2.wazuh["dashboard"].id
}

resource "openstack_networking_floatingip_v2" "salt_master" {
  pool = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "salt_master" {
  floating_ip = openstack_networking_floatingip_v2.salt_master.address
  port_id     = openstack_networking_port_v2.wazuh["salt-master"].id
}

resource "openstack_networking_floatingip_v2" "wazuh5" {
  pool = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "wazuh5" {
  floating_ip = openstack_networking_floatingip_v2.wazuh5.address
  port_id     = openstack_networking_port_v2.wazuh["wazuh5"].id
}
