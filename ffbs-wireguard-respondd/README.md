ffbs-wireguard-respondd
=======================

A respondd module to report basic statistics for WireGuard.

How it is used
--------------

This module can be added as a dependency in your `image-customization.lua`.
Afterwards you should be able to query `wireguard` from your `respondd`.

For a node with the following WireGuard interfaces:

```shell
root@Mhostname:~# wg
interface: wg_c1
  public key: K71ZNs4FurKnHc7mrUcuBfqLIi6IacRkPjAmq1bQ0A8=
  private key: (hidden)
  listening port: 35239
  fwmark: 0x1

peer: JQZCuxU/6RF7xbQ+hulFJ+RtyleAQ9JP5VP6S3vszlM=
  endpoint: [2a01:4f8:a0:6381::2]:10000
  allowed ips: 0.0.0.0/0, ::/0
  latest handshake: 1 minute, 42 seconds ago
  transfer: 176.93 GiB received, 12.07 GiB sent
  persistent keepalive: every 15 seconds

interface: wg_c3
  public key: K71ZNs4FurKnHc7mrUcuBfqLIi6IacRkPjAmq1bQ0A8=
  private key: (hidden)
  listening port: 32998
  fwmark: 0x1

peer: Gnfc/z9FDGiBC1eAi4TcnR2p5EmpE3zJTsA7KcNOnyo=
  endpoint: [2a0e:1580:1000::2dff:fe0e:e982]:10000
  allowed ips: 0.0.0.0/0, ::/0
  latest handshake: 32 seconds ago
  transfer: 12.19 GiB received, 1.27 GiB sent
  persistent keepalive: every 15 seconds
```

The response may look like this:

```shell
root@hostname:~# gluon-neighbour-info -r wireguard
{
  "interfaces": {
    "wg_c1": {
      "peers": {
        "JQZCuxU/6RF7xbQ+hulFJ+RtyleAQ9JP5VP6S3vszlM=": {
          "handshake": 92,
          "transfer_rx": 189973610414,
          "transfer_tx": 12955824977
        }
      }
    },
    "wg_c3": {
      "peers": {
        "Gnfc/z9FDGiBC1eAi4TcnR2p5EmpE3zJTsA7KcNOnyo=": {
          "handshake": 23,
          "transfer_rx": 13097904167,
          "transfer_tx": 1360334934
        }
      }
    }
  }
}
```
