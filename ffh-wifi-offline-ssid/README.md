ffh-wifi-offline-ssid
=====================

This package adds a script which changes the WLAN SSID on loss of
internet connectivity. It depends on and is being called by
*ffh-check-connection*.

This ``offline SSID`` can be generated from the node's hostname
with the first and last part of the node name or the MAC address.

After the connection has been lost for a certain ``threshold`` of
minutes it is being changed to the offline SSID.
Once the connectivity is established it will be changed back to
the default SSID again.

domain.conf
-----------

Adapt and add this block to your ``domain.conf``:

::

    ffh_wifi_offline_ssid = {
      disabled = false,
      target_group = 'targets_global',  -- the ffh-check-connection target group to perform tests on
      threshold = 5,                    -- the number of minutes after which connectivity is considered lost 
      prefix = 'Offline_',              -- use something short to leave space for the hostname (no '~' allowed!)
      suffix = 'hostname',              -- generate the SSID with either 'hostname', 'mac' or only the prefix: 'none'
    },


Configuration via UCI
---------------------

You can configure the offline SSID on the command line with ``uci``. 
E.g. disable it with:

::

    uci set ffh-wifi-offline-ssid.settings.disabled='1'

Or set the threshold to three minutes with

::

    uci set ffh-wifi-offline-ssid.settings.threshold='3'
