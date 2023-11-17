# gluon-ssid-changer

This package adds a script to change the SSID when there is no
connection to any gateway. This Offline-SSID can be generated from the
first and last part of the node\'s name or from the MAC address allowing
observers to recognize which node does not have a connection to a
gateway. This script is called once every minute by `micrond`. It will
change the SSID to the Offline-SSID after the node had no
gateway-connectivity for several consecutive checks. As soon as the
gateway-connectivity is back it toggles back to the original SSID.

You can enable/disable it in the config mode.

It checks if a gateway is reachable in an interval. Different algorithms
can be selected to determine whether a gateway is assumed reachable:

-   `tq_limit_enabled=true`: (not working with BATMAN_V) define an upper
    and lower bound to toggle the SSID. As long as the TQ stays
    in-between those bounds the SSID will not be changed.

-   `tq_limit_enabled=false`: there will be only checked, if the gateway
    is reachable with:

        batctl gwl -H

The SSID is always changed back to normal every minute as soon as the
gateway-connectivity is back.

The parameter `switch_timeframe` defines how long it will record the
gateway-connectivity. **Only** if the gateway is not reachable during at
least half the checks within `switch_timeframe` minutes, the SSID will
be changed to \"FF_Offline\_\$node_hostname\" (or \_\$node_mac)

The parameter `first` defines a learning phase after reboot (in minutes)
during which the SSID may be changed to the Offline-SSID **every
minute**.

# site.conf

Adapt and add this block to your `site.conf`:

    ssid_changer = {
      enabled = true,
      switch_timeframe = 30,    -- only once every timeframe (in minutes) the SSID will change to the Offline-SSID
                                -- set to 1440 to change once a day
                                -- set to 1 minute to change every time the router gets offline
      first = 5,                -- the first few minutes directly after reboot within which an Offline-SSID may be
                                -- activated every minute (must be <= switch_timeframe)
      prefix = 'FF_Offline_',   -- use something short to leave space for the nodename (no '~' allowed!)
      suffix = 'nodename',      -- generate the SSID with either 'nodename', 'mac' or to use only the prefix: 'none'

      tq_limit_enabled = false, -- if false, the offline SSID will only be set if there is no gateway reacheable
                                -- if true, set upper and lower limit to turn the offline_ssid on and off
                                -- in-between these two values the SSID will never be changed to prevent it from
                                -- toggeling every minute:
      tq_limit_max = 45,        -- upper limit, above that the online SSID will be used
      tq_limit_min = 35         -- lower limit, below that the offline SSID will be used
      debug_log_enabled = true, -- optional: enable extra debug logs
    },

# Commandline options

You can configure the ssid-changer on the commandline with `uci`, for
example disable it with:

    uci set ssid-changer.settings.enabled='0'

Or set the timeframe to every three minutes with

    uci set ssid-changer.settings.switch_timeframe='3'
    uci set ssid-changer.settings.first='3'

# Alternative: gluon-ssid-notifier

If you just need the Offline-SSID for administrative purposes, there is
a better solution, that will just add an extra SSID if a node is
offline: <https://github.com/freifunk-kiel/gluon-ssid-notifier/>

# Implement this package in your firmware

Create a file \"modules\" with the following content in your site
directory:

    GLUON_SITE_FEEDS="community"
    PACKAGES_SSIDCHANGER_REPO=https://github.com/freifunk-gluon/community-packages.git
    PACKAGES_SSIDCHANGER_COMMIT=f6db033d6568ea27805c9694b20085b8dec5ba87 # <-- set the newest commit ID here
    PACKAGES_SSIDCHANGER_BRANCH=master

With this done you can add the package `gluon-ssid-changer` to your
`site.mk`

# History

*This is a merge of https://github.com/ffac/gluon-ssid-changer and
https://github.com/viisauksena/gluon-ssid-changer and https://github.com/tecff/gluon-packages/tree/main/tecff-ssid-changer
Some SSID changers are in use in:

-   [Freifunk Aachen](https://github.com/ffac/gluon-ssid-changer/)
-   [Freifunk Kiel](https://github.com/freifunk-kiel/gluon-ssid-notifier)
-   Freifunk Kreis Gütersloh
-   [Freifunk Nord](https://github.com/Freifunk-Nord/gluon-ssid-changer)
-   [Eulenfunk](https://github.com/eulenfunk/packages/tree/v2020.1.x/gluon-ssid-changer)
-   Freifunk Vogtland
-   [Freifunk Berlin](https://github.com/freifunk-berlin/falter-packages/tree/master/packages/falter-berlin-ssid-changer)
-   [Freifunk Stuttgart](https://gitlab.freifunk-stuttgart.de/firmware/gluon-packages.git)
-   [Freifunk Altdorf](https://github.com/tecff/gluon-packages/tree/main/tecff-ssid-changer)
