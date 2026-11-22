Neighbour table
===============

The uplink node routes for all clients of its mesh. Each IPv6 client has
2 to 3 addresses. The kernel default limit (`gc_thresh3` = 1024) is full
at approximately 400 clients. Then the kernel drops packets
("neighbour table overflow").

The upgrade script `260-parker-neigh-limits` writes
`/etc/sysctl.d/41-parker-neigh.conf`. The limits apply to IPv4 and IPv6
and scale with the RAM:

| RAM            | gc_thresh1 | gc_thresh2 | gc_thresh3 |
|----------------|-----------:|-----------:|-----------:|
| up to 64 MiB   |        512 |       2048 |       4096 |
| up to 128 MiB  |       1024 |       4096 |       8192 |
| more           |       2048 |       8192 |      16384 |
