variable "api_key" {
  description = "NetActuate API key (from portal.netactuate.com/account/api)"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "PoP location code to deploy the router in (e.g., \"LAX\", \"FRA\", \"SIN\")"
  type        = string
  default     = "LAX"
}

variable "plan" {
  description = "Router plan (e.g., \"VR2x2x25\")"
  type        = string
  default     = "VR2x2x25"
}

variable "router_name" {
  description = "Name for the cloud router"
  type        = string
}

variable "local_asn" {
  description = "Local BGP autonomous system number"
  type        = string
  default     = "65002"
}

variable "remote_asn" {
  description = "Remote BGP peer autonomous system number"
  type        = number
  default     = 65001
}

variable "bgp_neighbor_address" {
  description = "IP address of the BGP neighbor peer"
  type        = string
  default     = "192.168.1.1"
}
