# netactuate-terraform-router -- AI Provisioning Context

Terraform module for NetActuate cloud routers with VRF, BGP, NAT, and advanced networking.
All 18 resource types are tested and working with provider >= 0.2.5.

Give me: API key + location + plan + router name + ASNs + neighbor address -> router deployed
with full networking stack.

## Required Inputs

| Input | Source | Example |
|-------|--------|---------|
| API key | portal.netactuate.com/account/api | `"abc123..."` |
| Location | Customer choice | `"LAX"` |
| Plan | Customer choice | `"VR2x2x25"` |
| Router name | Customer choice | `"my-router"` |
| Local ASN | Customer choice | `"65002"` |
| Remote ASN | Customer choice | `65001` |
| BGP neighbor | Customer network | `"192.168.1.1"` |

## What to Do

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Fill in values (never commit `terraform.tfvars`)
3. Run:
   ```bash
   terraform init
   terraform apply
   ```
4. Check outputs:
   ```bash
   terraform output router_id
   terraform output router_ipv4
   terraform output router_status
   ```

## Important Behavior

- **Serialized operations:** Router resources are created sequentially with a ~60s delay
  between each operation. This is by design in the provider. A full core deployment takes
  several minutes.
- **depends_on chains:** Every resource has an explicit `depends_on` to enforce ordering.
  Do not remove these or parallel creation will fail.
- **DHCP NTP gotcha:** The `ntp_servers.address` field in `netactuate_router_vrf_dhcp` MUST
  be an IPv4 address (e.g., `162.159.200.1`), not a hostname. Hostnames will cause failures.
- **Magic Mesh:** Requires 2+ routers. Enrolling a router restricts it to default VRF only.

## Advanced Features

The advanced sections in `main.tf` are commented out. To enable:

1. **IPSec VPN** -- Uncomment `netactuate_router_ipsec` and `netactuate_router_vrf_ipsec_peer`
2. **WireGuard peer** -- Uncomment `netactuate_router_vrf_interface_wireguard_peer`
3. **GRE tunnel** -- Uncomment `netactuate_router_vrf_tunnel`
4. **DHCP server** -- Uncomment `netactuate_router_vrf_dhcp` (remember: NTP must be an IP)
5. **Magic Mesh** -- Uncomment `netactuate_magic_mesh` and `netactuate_magic_mesh_router`

## Teardown

```bash
terraform destroy
```

## Common Errors

| Error | Fix |
|-------|-----|
| Provider not found | Run `terraform init` |
| API key invalid | Check `terraform.tfvars` -- key must be whitelisted on portal |
| Location not found | Check PoP code against portal API page |
| Operation timeout | Router operations take ~60s each; wait and retry |
| DHCP NTP failure | Use an IPv4 address, not a hostname, for `ntp_servers.address` |
