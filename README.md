# Wazuh test cluster on OpenStack

Terraform configuration for spinning up a Wazuh test cluster on OpenStack. Creates an isolated network with five nodes: `indexer`, `server`, `dashboard`, `client`, and `client2`. Only the dashboard node receives a floating IP.

## Requirements

- Terraform >= 1.3
- OpenStack credentials via `clouds.yaml` or a sourced `openrc` file
- An existing keypair in OpenStack

## Install
```bash
uv venv openstack-venv
source openstack-venv/bin/activate
uv pip install -r requirements.txt
```

## Usage

### 1. Configure

Copy the example vars file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Required variables:

| Variable | Description |
|---|---|
| `image_id` | Image UUID (pre-filled with the test cluster image) |
| `key_pair` | Name of your SSH keypair in OpenStack |
| `external_network_name` | Name of the external/provider network for the router and floating IPs |

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

After `apply`, Terraform outputs the floating IP of the dashboard node and the internal IPs of all nodes.

### 3. Tear down

```bash
terraform destroy
```

## Variables

| Variable | Default | Description |
|---|---|---|
| `network_name` | `wazuh` | Name of the internal network |
| `subnet_cidr` | `10.0.0.0/24` | CIDR of the internal subnet |
| `external_network_name` | `public` | External network for router/floating IPs |
| `dns_nameservers` | `8.8.8.8, 8.8.4.4` | DNS servers for the subnet |
| `flavor_name` | `hpc.v1.vm.8-16-160` | Flavor used for all nodes |
| `image_id` | — | Image UUID (**required**) |
| `key_pair` | — | SSH keypair name (**required**) |
| `allowed_cidr` | `0.0.0.0/0` | CIDR allowed SSH/HTTPS access to the dashboard |
| `ip_indexer` | `10.0.0.94` | Fixed internal IP of the indexer node |
| `ip_server` | `10.0.0.200` | Fixed internal IP of the server node |
| `ip_dashboard` | `10.0.0.60` | Fixed internal IP of the dashboard node |
| `ip_client` | `10.0.0.78` | Fixed internal IP of client |
| `ip_client2` | `10.0.0.99` | Fixed internal IP of client2 |

## Security groups

| Group | Rules |
|---|---|
| `wazuh-internal` | All inbound traffic between cluster nodes |
| `wazuh-dashboard` | TCP 22 (SSH) and TCP 443 (HTTPS) from `allowed_cidr` |
