

# WIFI eol at 15.11.2026

logread -f 
...
Sun Nov 15 19:06:21 2026 daemon.info fastd[2117]: resolving host `gw5.freifunk-3laendereck.net' for peer <mesh_vpn_backbone_peer_vpn5>...
Sun Nov 15 19:06:21 2026 daemon.info fastd[2117]: resolving host `gw3.ff3l.net' failed: Try again
Sun Nov 15 19:06:23 2026 daemon.info fastd[2117]: resolving host `gw4.ff3l.net' failed: Try again
Sun Nov 15 19:06:23 2026 daemon.info fastd[2117]: resolving host `gw9.freifunk-3laendereck.net' for peer <mesh_vpn_backbone_peer_vpn9>...
Sun Nov 15 19:06:24 2026 daemon.info fastd[2117]: resolving host `gw2.ff3l.net' failed: Try again
Sun Nov 15 19:06:25 2026 user.notice eol-ssid: client_radio0.ssid -> www.ff3l.net/veraltet
Sun Nov 15 19:06:25 2026 user.notice eol-ssid: wireless changed (date_ssid reached: true, date_wifi_off reached: false), reloading wifi
Sun Nov 15 19:06:25 2026 kern.info kernel: [31249.070102] device client0 left promiscuous mode
Sun Nov 15 19:06:25 2026 kern.info kernel: [31249.075188] br-client: port 4(client0) entered disabled state
Sun Nov 15 19:06:25 2026 user.notice eol-ssid: NTP hook: ACTION=periodic stratum=3
Sun Nov 15 19:06:25 2026 user.notice eol-ssid: Calling nagger
Sun Nov 15 19:06:25 2026 user.notice eol-ssid: Nagger exit code: 0
Sun Nov 15 19:06:25 2026 user.notice ntp-debug: action=periodic stratum=3 offset=-0.030622
Sun Nov 15 19:06:25 2026 daemon.notice hostapd: wan0: interface state ENABLED->DISABLED
Sun Nov 15 19:06:25 2026 daemon.notice hostapd: client0: AP-DISABLED
Sun Nov 15 19:06:25 2026 daemon.notice hostapd: client0: CTRL-EVENT-TERMINATING
Sun Nov 15 19:06:26 2026 daemon.notice hostapd: nl80211: Failed to remove interface client0 from bridge br-client: No such device
Sun Nov 15 19:06:26 2026 daemon.notice hostapd: wan0: AP-DISABLED
Sun Nov 15 19:06:26 2026 daemon.notice hostapd: wan0: CTRL-EVENT-TERMINATING
Sun Nov 15 19:06:26 2026 daemon.notice hostapd: nl80211: deinit ifname=wan0 disabled_11b_rates=0
Sun Nov 15 19:06:26 2026 kern.info kernel: [31249.758238] device wan0 left promiscuous mode
Sun Nov 15 19:06:26 2026 kern.info kernel: [31249.763204] br-wan: port 2(wan0) entered disabled state
Sun Nov 15 19:06:26 2026 daemon.notice netifd: Network device 'wan0' link is down
Sun Nov 15 19:06:26 2026 kern.info kernel: [31249.856714] batman_adv: bat0: Interface deactivated: mesh0
Sun Nov 15 19:06:26 2026 daemon.notice netifd: Network device 'mesh0' link is down
Sun Nov 15 19:06:26 2026 daemon.notice netifd: Interface 'mesh_radio0' has link connectivity loss
Sun Nov 15 19:06:26 2026 kern.info kernel: [31250.020697] batman_adv: bat0: Removing interface: mesh0
Sun Nov 15 19:06:26 2026 daemon.info fastd[2117]: resolving host `gw5.freifunk-3laendereck.net' failed: Try again
Sun Nov 15 19:06:26 2026 daemon.notice netifd: Interface 'mesh_radio0' is now down
Sun Nov 15 19:06:27 2026 daemon.notice netifd: wan (1369): udhcpc: performing DHCP renew
Sun Nov 15 19:06:28 2026 daemon.info fastd[2117]: resolving host `gw9.freifunk-3laendereck.net' failed: Try again
Sun Nov 15 19:06:28 2026 daemon.info fastd[2117]: resolving host `gw1.ff3l.net' for peer <mesh_vpn_backbone_peer_vpn1>...
Sun Nov 15 19:06:29 2026 daemon.err hostapd: Configuration file: /var/run/hostapd-phy0.conf
Sun Nov 15 19:06:29 2026 kern.info kernel: [31253.651557] IPv6: ADDRCONF(NETDEV_UP): wan0: link is not ready
Sun Nov 15 19:06:30 2026 kern.info kernel: [31253.753343] br-wan: port 2(wan0) entered blocking state
Sun Nov 15 19:06:30 2026 kern.info kernel: [31253.758619] br-wan: port 2(wan0) entered disabled state
Sun Nov 15 19:06:30 2026 kern.info kernel: [31253.764392] device wan0 entered promiscuous mode
Sun Nov 15 19:06:30 2026 daemon.notice hostapd: wan0: interface state UNINITIALIZED->COUNTRY_UPDATE
Sun Nov 15 19:06:30 2026 daemon.err hostapd: Using interface wan0 with hwaddr 8e:d3:e9:f7:18:c3 and ssid "BussNet"
Sun Nov 15 19:06:30 2026 kern.info kernel: [31254.523883] IPv6: ADDRCONF(NETDEV_CHANGE): wan0: link becomes ready
Sun Nov 15 19:06:30 2026 kern.info kernel: [31254.530533] br-wan: port 2(wan0) entered blocking state
Sun Nov 15 19:06:30 2026 kern.info kernel: [31254.535874] br-wan: port 2(wan0) entered forwarding state
Sun Nov 15 19:06:30 2026 kern.info kernel: [31254.563085] br-client: port 4(client0) entered blocking state
Sun Nov 15 19:06:30 2026 kern.info kernel: [31254.568887] br-client: port 4(client0) entered disabled state
Sun Nov 15 19:06:30 2026 kern.info kernel: [31254.575357] device client0 entered promiscuous mode
Sun Nov 15 19:06:30 2026 kern.info kernel: [31254.602235] IPv6: ADDRCONF(NETDEV_UP): client0: link is not ready
Sun Nov 15 19:06:30 2026 kern.info kernel: [31254.608586] br-client: port 4(client0) entered blocking state
Sun Nov 15 19:06:30 2026 kern.info kernel: [31254.614441] br-client: port 4(client0) entered forwarding state
Sun Nov 15 19:06:30 2026 daemon.err hostapd: Using interface client0 with hwaddr 8e:d3:e9:f7:18:c0 and ssid "www.ff3l.net/veraltet"
Sun Nov 15 19:06:31 2026 daemon.notice hostapd: wan0: interface state COUNTRY_UPDATE->ENABLED
Sun Nov 15 19:06:31 2026 daemon.notice hostapd: wan0: AP-ENABLED
Sun Nov 15 19:06:31 2026 kern.info kernel: [31254.656682] IPv6: ADDRCONF(NETDEV_CHANGE): client0: link becomes ready
Sun Nov 15 19:06:31 2026 kern.info kernel: [31255.019413] IPv6: ADDRCONF(NETDEV_UP): mesh0: link is not ready
Sun Nov 15 19:06:31 2026 kern.info kernel: [31255.178885] IPv6: ADDRCONF(NETDEV_CHANGE): mesh0: link becomes ready
Sun Nov 15 19:06:31 2026 daemon.notice netifd: Network device 'wan0' link is up
Sun Nov 15 19:06:31 2026 daemon.notice netifd: Network device 'mesh0' link is up
Sun Nov 15 19:06:31 2026 daemon.notice netifd: Interface 'mesh_radio0' has link connectivity
Sun Nov 15 19:06:31 2026 daemon.notice netifd: Interface 'mesh_radio0' is setting up now
Sun Nov 15 19:06:31 2026 daemon.notice netifd: Network device 'client0' link is up
Sun Nov 15 19:06:32 2026 daemon.notice netifd: wan (1369): udhcpc: performing DHCP renew
Sun Nov 15 19:06:32 2026 daemon.notice netifd: Interface 'mesh_radio0' is now up
Sun Nov 15 19:06:32 2026 kern.info kernel: [31256.296842] batman_adv: bat0: Adding interface: mesh0
Sun Nov 15 19:06:32 2026 kern.info kernel: [31256.302023] batman_adv: bat0: Interface activated: mesh0
Sun Nov 15 19:06:32 2026 user.notice firewall: Reloading firewall due to ifup of mesh_radio0 (mesh0)
Sun Nov 15 19:06:33 2026 daemon.info fastd[2117]: resolving host `gw6.freifunk-3laendereck.net' for peer <mesh_vpn_backbone_peer_vpn6>...
Sun Nov 15 19:06:33 2026 daemon.info fastd[2117]: resolving host `gw8.ff3l.net' for peer <mesh_vpn_backbone_peer_vpn8>...
Sun Nov 15 19:06:33 2026 daemon.info fastd[2117]: resolving host `gw1.ff3l.net' failed: Try again
Sun Nov 15 19:06:35 2026 daemon.info fastd[2117]: resolving host `gw7.freifunk-3laendereck.net' for peer <mesh_vpn_backbone_peer_vpn7>...
Sun Nov 15 19:06:37 2026 daemon.info fastd[2117]: resolving host `gw3.ff3l.net' for peer <mesh_vpn_backbone_peer_vpn3>...
Sun Nov 15 19:06:38 2026 daemon.info fastd[2117]: resolving host `gw4.ff3l.net' for peer <mesh_vpn_backbone_peer_vpn4>...
Sun Nov 15 19:06:38 2026 daemon.info fastd[2117]: resolving host `gw6.freifunk-3laendereck.net' failed: Try again
Sun Nov 15 19:06:38 2026 daemon.info fastd[2117]: resolving host `gw8.ff3l.net' failed: Try again



# WIFI off at 16.11.2026

logread -f 

...
Mon Nov 16 16:32:55 2026 user.notice eol-ssid: client_radio0.disabled -> true
Mon Nov 16 16:32:55 2026 user.notice eol-ssid: wireless changed (date_ssid reached: true, date_wifi_off reached: true), reloading wifi
Mon Nov 16 16:32:55 2026 kern.info kernel: [  796.784198] device client0 left promiscuous mode
Mon Nov 16 16:32:55 2026 kern.info kernel: [  796.789024] br-client: port 4(client0) entered disabled state
Mon Nov 16 16:32:55 2026 user.notice eol-ssid: NTP hook: ACTION=stratum stratum=3
Mon Nov 16 16:32:55 2026 user.notice eol-ssid: Calling nagger
Mon Nov 16 16:32:56 2026 user.notice eol-ssid: client_radio0.disabled -> true
Mon Nov 16 16:32:56 2026 user.notice eol-ssid: wireless changed (date_ssid reached: true, date_wifi_off reached: true), reloading wifi
Mon Nov 16 16:32:56 2026 user.notice eol-ssid: Nagger exit code: 0
Mon Nov 16 16:32:56 2026 user.notice ntp-debug: action=stratum stratum=3 offset=0.005398
Mon Nov 16 16:32:57 2026 daemon.notice hostapd: wan0: interface state ENABLED->DISABLED
Mon Nov 16 16:32:57 2026 daemon.notice hostapd: client0: AP-DISABLED
Mon Nov 16 16:32:57 2026 daemon.notice hostapd: client0: CTRL-EVENT-TERMINATING
Mon Nov 16 16:32:57 2026 daemon.notice hostapd: nl80211: Failed to remove interface client0 from bridge br-client: No such device
Mon Nov 16 16:32:57 2026 daemon.notice hostapd: wan0: AP-DISABLED
Mon Nov 16 16:32:57 2026 daemon.notice hostapd: wan0: CTRL-EVENT-TERMINATING
Mon Nov 16 16:32:57 2026 daemon.notice hostapd: nl80211: deinit ifname=wan0 disabled_11b_rates=0
...




Mon Nov 16 17:39:01 2026 user.notice gluon-offline-ssid: TQ is 217, SSID is www.ff3l.net/veraltet, change to FF_OFFLINE_ff3l-siki-3
