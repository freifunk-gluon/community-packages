# DDHCPD OLSRD integration

Integration of DDHCPD into OLSRD v1/v2 networks. The contained script
`ddhcpd-gateway-update` manages the configuration of gateway and DNS server DHCP
options, so clients can be configured with the right information.

This script simply checks what gateways peers are announcing and then picks
one of them.

If none is found the gateway will be removed and ddhcpd will not announce it
