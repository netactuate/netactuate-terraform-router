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

  server {
    address = "0.pool.ntp.org"
  }

  server {
    address = "1.pool.ntp.org"
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
    cidr = "192.168.0.0/24"
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
  router_id = netactuate_router.router.id
  prefix    = "10.10.0.0/24"
  next_hop  = "192.168.0.1"
  interface = netactuate_router_vrf_interface.dummy.name

  depends_on = [netactuate_router_vrf_bgp_neighbor.peer]
}

resource "netactuate_router_prefix_list" "ipv4" {
  router_id = netactuate_router.router.id
  name      = "ipv4-filter"
  family    = "ipv4"

  rule {
    action = "permit"
    prefix = "192.168.0.0/16"
    le     = 24
  }

  rule {
    action = "deny"
    prefix = "0.0.0.0/0"
    le     = 32
  }

  depends_on = [netactuate_router_static_route.default]
}

resource "netactuate_router_prefix_list" "ipv6" {
  router_id = netactuate_router.router.id
  name      = "ipv6-filter"
  family    = "ipv6"

  rule {
    action = "permit"
    prefix = "2001:db8::/32"
    le     = 48
  }

  rule {
    action = "deny"
    prefix = "::/0"
    le     = 128
  }

  depends_on = [netactuate_router_prefix_list.ipv4]
}

# -----------------------------------------------------------------------------
# NAT — SNAT & DNAT
# -----------------------------------------------------------------------------

resource "netactuate_router_vrf_snat_rule" "outbound" {
  router_id = netactuate_router.router.id
  vrf_id    = netactuate_router.router.default_vrf_id

  match {
    interface = "eth0"
    network   = "192.168.0.0/24"
    port      = "1024-65535"
  }

  depends_on = [netactuate_router_prefix_list.ipv6]
}

resource "netactuate_router_vrf_dnat_rule" "inbound" {
  router_id = netactuate_router.router.id
  vrf_id    = netactuate_router.router.default_vrf_id

  match {
    interface = "eth0"
    network   = "0.0.0.0/0"
    port      = "8080"
  }

  depends_on = [netactuate_router_vrf_snat_rule.outbound]
}

# -----------------------------------------------------------------------------
# Advanced — IPSec VPN (Uncomment to enable)
# -----------------------------------------------------------------------------

# resource "netactuate_router_ipsec" "config" {
#   router_id       = netactuate_router.router.id
#   ike_version     = 2
#   encryption      = "aes256"
#   hash            = "sha256"
#   dh_group        = 14
#
#   depends_on = [netactuate_router_vrf_dnat_rule.inbound]
# }
#
# resource "netactuate_router_vrf_ipsec_peer" "remote" {
#   router_id              = netactuate_router.router.id
#   vrf_id                 = netactuate_router.router.default_vrf_id
#   peer_address           = "203.0.113.1"
#   pre_shared_key         = "change-me-to-a-strong-secret"
#   overlay_ip             = "10.255.0.1/30"
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
#   interface_id = netactuate_router_vrf_interface.wireguard.id
#   public_key   = "PEER_PUBLIC_KEY_BASE64"
#   endpoint     = "203.0.113.2:51821"
#
#   allowed_ips {
#     cidr = "10.0.0.2/32"
#   }
#
#   depends_on = [netactuate_router_vrf_interface.wireguard]
# }

# -----------------------------------------------------------------------------
# Advanced — GRE Tunnel (Uncomment to enable)
# -----------------------------------------------------------------------------

# resource "netactuate_router_vrf_tunnel" "gre" {
#   router_id = netactuate_router.router.id
#   vrf_id    = netactuate_router.router.default_vrf_id
#   ip_key    = "10.255.1.1/30"
#   mtu       = 1476
#   remote    = "203.0.113.3"
#
#   depends_on = [netactuate_router_vrf_dnat_rule.inbound]
# }

# -----------------------------------------------------------------------------
# Advanced — DHCP Server (Uncomment to enable)
# NOTE: ntp_servers.address MUST be an IPv4 address, not a hostname — hostnames fail.
# -----------------------------------------------------------------------------

# resource "netactuate_router_vrf_dhcp" "lan" {
#   router_id = netactuate_router.router.id
#   vrf_id    = netactuate_router.router.default_vrf_id
#
#   subnet = "192.168.0.0/24"
#
#   range {
#     start = "192.168.0.100"
#     stop  = "192.168.0.200"
#   }
#
#   dns_servers {
#     address = "1.1.1.1"
#   }
#
#   dns_servers {
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
