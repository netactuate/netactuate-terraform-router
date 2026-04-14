terraform {
  required_providers {
    netactuate = {
      source  = "netactuate/netactuate"
      version = ">= 0.2.5"
    }
  }
  required_version = ">= 1.0"
}

provider "netactuate" {
  api_key = var.api_key
}

# -----------------------------------------------------------------------------
# Core — Router
# -----------------------------------------------------------------------------

resource "netactuate_router" "router" {
  name        = var.router_name
  description = "Cloud router managed by Terraform"
  location    = var.location
  plan        = var.plan
}

resource "netactuate_router_ntp" "ntp" {
  router_id = netactuate_router.router.id
  enabled   = true

  upstreams {
    domain = "0.pool.ntp.org"
  }

  upstreams {
    domain = "1.pool.ntp.org"
  }

  depends_on = [netactuate_router.router]
}

# -----------------------------------------------------------------------------
# Interfaces
# -----------------------------------------------------------------------------

resource "netactuate_router_vrf_interface" "dummy" {
  router_id = netactuate_router.router.id
  vrf_id    = netactuate_router.router.default_vrf_id
  name      = "dummy0"
  type      = "dummy"
  ipv4_cidr = "192.168.0.1/24"

  depends_on = [netactuate_router_ntp.ntp]
}

resource "netactuate_router_vrf_interface" "wireguard" {
  router_id      = netactuate_router.router.id
  vrf_id         = netactuate_router.router.default_vrf_id
  name           = "wg0"
  type           = "wireguard"
  ipv4_cidr      = "10.0.0.1/24"
  wireguard_port = 51821

  depends_on = [netactuate_router_vrf_interface.dummy]
}

# -----------------------------------------------------------------------------
# BGP
# -----------------------------------------------------------------------------

resource "netactuate_router_vrf_bgp" "bgp" {
  router_id = netactuate_router.router.id
  vrf_id    = netactuate_router.router.default_vrf_id
  local_asn = var.local_asn

  networks {
    subnet = "192.168.0.0/24"
  }

  depends_on = [netactuate_router_vrf_interface.wireguard]
}

resource "netactuate_router_vrf_bgp_neighbor" "peer" {
  router_id    = netactuate_router.router.id
  vrf_id       = netactuate_router.router.default_vrf_id
  address      = var.bgp_neighbor_address
  remote_asn   = var.remote_asn
  ipv4_enabled = true
  ipv6_enabled = true

  depends_on = [netactuate_router_vrf_bgp.bgp]
}

# -----------------------------------------------------------------------------
# Routing — Static Route & Prefix Lists
# -----------------------------------------------------------------------------

resource "netactuate_router_static_route" "default" {
  router_id    = netactuate_router.router.id
  vrf_id       = netactuate_router.router.default_vrf_id
  network      = "10.10.0.0/24"
  next_hop     = "192.168.0.1"
  interface_id = netactuate_router_vrf_interface.dummy.interface_id

  depends_on = [netactuate_router_vrf_bgp_neighbor.peer]
}

resource "netactuate_router_prefix_list" "ipv4" {
  router_id  = netactuate_router.router.id
  name       = "ipv4-filter"
  ip_version = 4

  rule {
    action = "permit"
    prefix = "192.168.0.0/16"
  }

  rule {
    action = "deny"
    prefix = "0.0.0.0/0"
  }

  depends_on = [netactuate_router_static_route.default]
}

resource "netactuate_router_prefix_list" "ipv6" {
  router_id  = netactuate_router.router.id
  name       = "ipv6-filter"
  ip_version = 6

  rule {
    action = "permit"
    prefix = "2001:db8::/32"
  }

  rule {
    action = "deny"
    prefix = "::/0"
  }

  depends_on = [netactuate_router_prefix_list.ipv4]
}

# -----------------------------------------------------------------------------
# NAT — SNAT & DNAT
# -----------------------------------------------------------------------------

resource "netactuate_router_vrf_snat_rule" "outbound" {
  router_id          = netactuate_router.router.id
  vrf_id             = netactuate_router.router.default_vrf_id
  ip_version         = 4
  protocol           = "TCP"
  match_interface_id = netactuate_router_vrf_interface.dummy.interface_id
  match_network      = "192.168.0.0/24"
  match_port_start   = 1024
  match_port_end     = 32000
  translation_network    = "0.0.0.0/0"
  translation_port_start = 1024
  translation_port_end   = 32000

  depends_on = [netactuate_router_prefix_list.ipv6]
}

resource "netactuate_router_vrf_dnat_rule" "inbound" {
  router_id          = netactuate_router.router.id
  vrf_id             = netactuate_router.router.default_vrf_id
  ip_version         = 4
  protocol           = "TCP"
  match_interface_id = netactuate_router_vrf_interface.dummy.interface_id
  match_network      = "0.0.0.0/0"
  match_port_start   = 8080
  match_port_end     = 8080
  translation_network    = "192.168.0.10/32"
  translation_port_start = 80
  translation_port_end   = 80

  depends_on = [netactuate_router_vrf_snat_rule.outbound]
}

# -----------------------------------------------------------------------------
# Advanced — IPSec VPN (Uncomment to enable)
# -----------------------------------------------------------------------------

# resource "netactuate_router_ipsec" "config" {
#   router_id                = netactuate_router.router.id
#   ike_key_exchange_version = 2
#   ike_encryption           = "aes256"
#   ike_hash                 = "sha256"
#   ike_dh_group_number      = 14
#   esp_encryption           = "aes256"
#   esp_hash                 = "sha256"
#
#   depends_on = [netactuate_router_vrf_dnat_rule.inbound]
# }
#
# resource "netactuate_router_vrf_ipsec_peer" "remote" {
#   router_id              = netactuate_router.router.id
#   vrf_id                 = netactuate_router.router.default_vrf_id
#   name                   = "remote-site"
#   remote_id              = "remote-router"
#   peer_address           = "203.0.113.1"
#   psk_secret             = "change-me-to-a-strong-secret"
#   overlay_ipv4           = "10.255.0.1/30"
#   do_initiate_connection = true
#
#   depends_on = [netactuate_router_ipsec.config]
# }

# -----------------------------------------------------------------------------
# Advanced — WireGuard Peer (Uncomment to enable)
# -----------------------------------------------------------------------------

# resource "netactuate_router_vrf_interface_wireguard_peer" "peer1" {
#   router_id    = netactuate_router.router.id
#   vrf_id       = netactuate_router.router.default_vrf_id
#   interface_id = netactuate_router_vrf_interface.wireguard.interface_id
#   public_key   = "PEER_PUBLIC_KEY_BASE64"
#   remote       = "203.0.113.2:51821"
#
#   allowed_ips {
#     network = "10.0.0.2/32"
#   }
#
#   depends_on = [netactuate_router_vrf_interface.wireguard]
# }

# -----------------------------------------------------------------------------
# Advanced — GRE Tunnel (Uncomment to enable)
# -----------------------------------------------------------------------------

# resource "netactuate_router_vrf_tunnel" "gre" {
#   router_id              = netactuate_router.router.id
#   vrf_id                 = netactuate_router.router.default_vrf_id
#   name                   = "gre-tunnel-1"
#   ip_key                 = 100
#   mtu                    = 1476
#   endpoint_address_remote = "203.0.113.3"
#   ipv4_cidr              = "10.255.1.1/30"
#
#   depends_on = [netactuate_router_vrf_dnat_rule.inbound]
# }

# -----------------------------------------------------------------------------
# Advanced — DHCP Server (Uncomment to enable)
# NOTE: ntp_servers.address MUST be an IPv4 address, not a hostname — hostnames fail.
# -----------------------------------------------------------------------------

# resource "netactuate_router_vrf_dhcp" "lan" {
#   router_id    = netactuate_router.router.id
#   vrf_id       = netactuate_router.router.default_vrf_id
#   enabled      = true
#   interface_id = netactuate_router_vrf_interface.dummy.interface_id
#   subnet       = "192.168.0.0/24"
#
#   range {
#     first_address = "192.168.0.100"
#     last_address  = "192.168.0.200"
#   }
#
#   domain_name_servers {
#     address = "1.1.1.1"
#   }
#
#   domain_name_servers {
#     address = "8.8.8.8"
#   }
#
#   ntp_servers {
#     address = "162.159.200.1"
#   }
#
#   depends_on = [netactuate_router_vrf_interface.dummy]
# }

# -----------------------------------------------------------------------------
# Advanced — Magic Mesh (Uncomment to enable)
# NOTE: Requires 2+ routers. Enrolling a router restricts it to default VRF only.
# -----------------------------------------------------------------------------

# resource "netactuate_magic_mesh" "mesh" {
#   name        = "my-mesh"
#   description = "Magic Mesh network"
# }
#
# resource "netactuate_magic_mesh_router" "enroll" {
#   magic_mesh_id = netactuate_magic_mesh.mesh.id
#   router_id     = netactuate_router.router.id
#
#   depends_on = [netactuate_magic_mesh.mesh]
# }
