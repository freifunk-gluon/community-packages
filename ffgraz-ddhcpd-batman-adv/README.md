# DDHCPD BATMAN-ADV integration

Integration of DDHCPD into batman-adv networks. The contained script
`ddhcpd-gateway-update` manages the configuration of gateway and DNS server DHCP
options, so clients can be configured with the right information.

_Knowing the IP address of a gateway can be a hassle in batman-adv networks._

## Configuration

Make sure your gateways use the same MAC address for their batman interface and
the primary batman interface (which may also be a bridge) all the time.
You need to install [mesh-announce](https://github.com/ffnord/mesh-announce) on
your gateways, so DDHCPD can query the gateway address that should be announced
over DHCP via `respondd` from the chosen gateway.

Further reading, see [ddhcpd README](../ddhcpd/README.md).
