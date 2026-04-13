output "router_id" {
  description = "ID of the provisioned cloud router"
  value       = netactuate_router.router.id
}

output "router_ipv4" {
  description = "Primary IPv4 address of the router"
  value       = netactuate_router.router.primary_ipv4
}

output "router_status" {
  description = "Current status of the router"
  value       = netactuate_router.router.status
}

output "default_vrf_id" {
  description = "Default VRF ID of the router"
  value       = netactuate_router.router.default_vrf_id
}

output "dummy_interface_id" {
  description = "ID of the dummy interface"
  value       = netactuate_router_vrf_interface.dummy.id
}

output "wireguard_interface_id" {
  description = "ID of the WireGuard interface"
  value       = netactuate_router_vrf_interface.wireguard.id
}
