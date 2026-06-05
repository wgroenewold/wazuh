variable "network_name" {
  description = "Internal Wazuh network name"
  type        = string
  default     = "wazuh"
}

variable "subnet_cidr" {
  description = "CIDR of internal subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "external_network_name" {
  description = "External network name"
  type        = string
  default     = "external"
}

variable "dns_nameservers" {
  description = "DNS servers for the subnet"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "allowed_cidr" {
  description = "CIDR that can access dashboard"
  type        = string
  default     = "0.0.0.0/0"
}

variable "flavor_name" {
  description = "OpenStack flavor for all the nodes"
  type        = string
  default     = "hpc.v1.vm.8-16-160"
}

variable "image_id" {
  description = "Image name"
  type        = string
}

variable "key_pair" {
  description = "SSH keypair name"
  type        = string
}

# Static IP
variable "ip_indexer" {
  type    = string
  default = "10.0.0.94"
}

variable "ip_server" {
  type    = string
  default = "10.0.0.200"
}

variable "ip_dashboard" {
  type    = string
  default = "10.0.0.60"
}

variable "ip_client" {
  type    = string
  default = "10.0.0.78"
}

variable "ip_client2" {
  type    = string
  default = "10.0.0.99"
}
