# netactuate-terraform-router

NetActuate Terraform Cloud Router -- deploy a cloud router with VRF, BGP peering, static routes,
prefix lists, NAT rules, and advanced networking with a single `terraform apply`.

### NetActuate Terraform Provider

The NetActuate Terraform provider is installed automatically when you run `terraform init`.
It is downloaded from the Terraform Registry and shared across all modules on your system.
Each module in this collection is an independent, self-contained project with its own
`main.tf`, `variables.tf`, and `outputs.tf` -- you can use any module on its own without
the others.

## What This Deploys

- A cloud router with NTP configuration
- VRF interfaces (dummy, WireGuard)
- BGP peering with configurable ASNs
- Static routes and prefix lists (IPv4 + IPv6)
- Source NAT and destination NAT rules

Optional advanced features (commented out, ready to enable):
- IPSec VPN tunnels
- WireGuard peers
- GRE tunnels
- DHCP server
- Magic Mesh overlay network

> **Note:** Router operations are serialized by the provider with a ~60s delay between
> operations. A full apply with all core resources takes several minutes. This is expected.

## Prerequisites

- **Terraform 1.0+** or **OpenTofu**
- A NetActuate API key ([portal.netactuate.com/account/api](https://portal.netactuate.com/account/api))

### Install Terraform

**macOS:**
```bash
brew install terraform
```

**Linux:**
```bash
# Using tfenv
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
tfenv install latest
tfenv use latest
```

Or download the binary directly from [terraform.io/downloads](https://www.terraform.io/downloads).

**Windows:**
```powershell
winget install Hashicorp.Terraform
```

Or use WSL2 with the Linux instructions above.

## Configuration

### Step 1: Copy the example tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

**Never commit `terraform.tfvars`** -- it contains your API key and is gitignored.

### Step 2: Fill in your values

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `api_key` | string | -- | NetActuate API key (sensitive) |
| `location` | string | `"LAX"` | PoP location code |
| `plan` | string | `"VR2x2x25"` | Router sizing plan |
| `router_name` | string | -- | Name for the cloud router |
| `local_asn` | string | `"65002"` | Local BGP ASN |
| `remote_asn` | number | `65001` | Remote BGP peer ASN |
| `bgp_neighbor_address` | string | `"192.168.1.1"` | BGP neighbor IP address |

## Usage

```bash
# Initialize providers
terraform init

# Preview what will be created
terraform plan

# Deploy the router and all networking
terraform apply

# View router details
terraform output router_id
terraform output router_ipv4
terraform output router_status
```

## Advanced Features

The following features are included in `main.tf` as commented-out blocks. Uncomment the
relevant section and configure the values for your environment.

### IPSec VPN

Site-to-site VPN using IKEv2 with AES-256 encryption and SHA-256 hashing.

To enable:
1. Uncomment the `netactuate_router_ipsec` and `netactuate_router_vrf_ipsec_peer` blocks
2. Set `peer_address` to your remote VPN endpoint
3. Set `psk_secret` to a strong shared secret
4. Set `name`, `remote_id`, and adjust `overlay_ipv4` for your tunnel addressing

### WireGuard

Lightweight VPN tunnel using the WireGuard protocol. The WireGuard interface is already
created by default -- this section adds a peer to it.

To enable:
1. Uncomment the `netactuate_router_vrf_interface_wireguard_peer` block
2. Set `public_key` to your peer's WireGuard public key
3. Set `remote` to the peer's IP and port
4. Adjust `allowed_ips` for your network

### GRE Tunnels

Generic Routing Encapsulation tunnel for connecting to remote networks.

To enable:
1. Uncomment the `netactuate_router_vrf_tunnel` block
2. Set `endpoint_address_remote` to the far-end tunnel endpoint IP
3. Set `ip_key` (GRE key, integer), `name`, and `mtu` as needed

### DHCP Server

Run a DHCP server on the router to assign addresses to connected clients.

To enable:
1. Uncomment the `netactuate_router_vrf_dhcp` block
2. Adjust `subnet`, `range`, `domain_name_servers`, and `ntp_servers` for your network
3. **Important:** `ntp_servers.address` must be an IPv4 address, not a hostname -- hostnames
   will fail

### Magic Mesh

NetActuate's overlay mesh network that automatically connects enrolled routers.

To enable:
1. Uncomment the `netactuate_magic_mesh` and `netactuate_magic_mesh_router` blocks
2. Set a name and description for the mesh

> **Note:** Magic Mesh requires 2 or more routers. Enrolling a router in a mesh restricts
> it to the default VRF only. To build a multi-router mesh, deploy additional routers and
> enroll them in the same `netactuate_magic_mesh` resource.

## Teardown

```bash
terraform destroy
```

This removes the router and all associated resources, and cancels billing.

## AI-Assisted (Claude Code / Cursor / Copilot)

```
Deploy a NetActuate cloud router with Terraform:

- API Key: <YOUR_API_KEY>
- Location: LAX
- Plan: VR2x2x25
- Router name: my-router
- Local ASN: 65002
- Remote ASN: 65001
- BGP neighbor: 192.168.1.1

Please:
1. Copy terraform.tfvars.example to terraform.tfvars and fill in values
2. Run terraform init && terraform apply
3. Show me the router_ipv4 output
```

## Need Help?

- NetActuate support: support@netactuate.com
- [NetActuate API Documentation](https://www.netactuate.com/docs/)
- [Terraform NetActuate Provider](https://registry.terraform.io/providers/netactuate/netactuate/latest)
- [NetActuate Portal](https://portal.netactuate.com)
