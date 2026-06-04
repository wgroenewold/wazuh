variable "network_name" {
  description = "Naam van het interne Wazuh netwerk"
  type        = string
  default     = "wazuh"
}

variable "subnet_cidr" {
  description = "CIDR van het interne subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "external_network_name" {
  description = "Naam van het externe netwerk (voor floating IPs en router)"
  type        = string
  default     = "public"
}

variable "dns_nameservers" {
  description = "DNS servers voor het subnet"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "allowed_cidr" {
  description = "CIDR die SSH/HTTPS mag benaderen op de dashboard node"
  type        = string
  default     = "0.0.0.0/0"
}

variable "flavor_name" {
  description = "OpenStack flavor voor alle nodes"
  type        = string
  default     = "hpc.v1.vm.8-16-160"
}

variable "image_id" {
  description = "Image UUID (zelfde voor alle nodes)"
  type        = string
  # 72448fdb-f797-45ef-a192-ddaf58d58f6c
}

variable "key_pair" {
  description = "Naam van het SSH keypair in OpenStack"
  type        = string
}

# Vaste IP-adressen per node (passend in subnet_cidr)
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
