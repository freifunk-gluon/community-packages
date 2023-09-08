# DDHCPD

## Integration of DDHCPD in gluon

Add the feed https://github.com/ffgraz/community-packages to your `modules` config, if not already added,
then add the package `ffgraz-ddhcpd` (or `ffgraz-ddhcpd-nextnode`, `ffgraz-ddhcpd-batman-adv`, depending on your use case) to your `site.mk` and add a
section in your `site.conf`:

    ddhcpd = {
      range = "10.187.124.0/22",    -- Network to announce and manage blocks in
                                    -- optional fine-tuning:
      -- enabled = true,            -- (default: true)
      -- block_size = 2,            -- Power over two of block size (default: 2)
      -- block_timeout = 300,       -- Timeout in seconds until a claimed block is released (default: 300)
      -- dhcp_lease_time = 300,     -- DHCP lease time in seconds (default: 300)
      -- spare_leases = 2,          -- Amount of spare leases (max: 256, default: 2)
      -- tentative_timeout = 15,    -- Time in seconds from when a block is announced to be claimed until a block is claimed (min:3, default: 15)
    },

Set enabled to `false` if you don't want DDHCPD to be enabled by default on your
nodes.

Choose a free IP-range that is not used by the DHCP-servers of your gateways
that the DDHCPD can use to assign to clients.

If you use B.A.T.M.A.N., continue reading the _Configuration_ section in
[ddhcpd-batman-adv README](../ffgraz-ddhcpd-batman-adv/README.md#Configuration)


#### disable DDHCPD with one shell call:

     ssh <router ip> 'uci set ddhcpd.enabled="0"; uci commit ddhcpd && /etc/init.d/ddhcpd restart; echo done'

All other values can be changed via `uci set` also, but all settings except
`enabled` are reset to the default value set in your `site.conf` on reboot.

## More

More detailed documentation regarding DDHCPD itself can be found at
https://github.com/sargon/ddhcpd/blob/master/README
