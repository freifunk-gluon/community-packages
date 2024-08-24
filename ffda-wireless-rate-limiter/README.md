# ffda-wireless-rate-limiter

This package provides a rate-limiter which can shape traffic per client
and per interface. The limit is user-configurable and defaults can be
applied and updated via the site-config.

## Examples
### Site

Below you can see an example of how to configure the rate-limiter
in the site-configuration.

Each client is shaped to a different rate.

 - On 5 GHz, only the uplink will be shaped.
 - On 2.4 GHz, both uplink and downlink will be shaped. Additionally,
   all traffic on the 2.4 GHz radios will each be shaped to a maximum
   of 10 Mbit/s downlink and 5 Mbit/s uplink.

When using OWE, the limits are imposed for the unencrypted and OWE network
indepedently.

```lua
wifi24 = {
	channel = 5, -- 2432 MHz

	rate_limit = {
		client = {
			down = 6000, -- 6 Mbit/s
			up = 3000, -- 3 Mbit/s
		},
		iface = {
			down = 10000, -- 10 Mbit/s
			up = 5000, -- 5 Mbit/s
		},
	},

	mesh = {
		mcast_rate = 12000,
	},
},
wifi5 = {
	channel = 48, -- 5230 MHz
	outdoor_chanlist = '96-116 132-140',

	rate_limit = {
		client = {
			up = 6000, -- 6 Mbit/s
		},
	},

	mesh = {
		mcast_rate = 12000,
	},
},
```

### UCI

The rate-limiter can also be configured via UCI. The following example is
for a configuration which is equivalent to the site-configuration above.

Take note however: If you intend to remove
limits imposed by the site-configuration, you need to set the values to
`0` instead of removing the sections.

```sh
uci set gluon.rate_limit_2g=ffda-rate-limit
uci set gluon.rate_limit_2g.band='2g'
uci set gluon.rate_limit_2g.client_down=6000
uci set gluon.rate_limit_2g.client_up=3000
uci set gluon.rate_limit_2g.iface_down=10000
uci set gluon.rate_limit_2g.iface_up=5000

uci set gluon.rate_limit_5g=ffda-rate-limit
uci set gluon.rate_limit_5g.band='5g'
uci set gluon.rate_limit_5g.client_down=0
uci set gluon.rate_limit_5g.client_up=2000
uci set gluon.rate_limit_5g.iface_down=10000
uci set gluon.rate_limit_5g.iface_up=5000

uci commit gluon
```
