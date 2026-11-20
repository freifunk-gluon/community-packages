#!/usr/bin/env python3
# DHCP client for dhcp-authoritative-test.sh.
# Usage: dhcp-authoritative-client.py TYPE SERVER CIADDR [REQUESTED SERVER_ID]
# TYPE: discover, request. SERVER: the destination address. Prints the type of
# the answer (offer, ack, nak) or "none" after 3 s.
import socket, struct, sys

kind, dest, ciaddr = sys.argv[1], sys.argv[2], sys.argv[3]
requested = sys.argv[4] if len(sys.argv) > 4 else None
server_id = sys.argv[5] if len(sys.argv) > 5 else None
mac = bytes.fromhex("020000000050")
xid = 0x12345678
opts = bytes([53, 1, 1 if kind == "discover" else 3])
if requested:
    opts += bytes([50, 4]) + socket.inet_aton(requested)
if server_id:
    opts += bytes([54, 4]) + socket.inet_aton(server_id)
opts += bytes([255])
flags = 0x8000 if ciaddr == "0.0.0.0" else 0
pkt = struct.pack(
    "!BBBBIHH4s4s4s4s16s64s128s", 1, 1, 6, 0, xid, 0, flags,
    socket.inet_aton(ciaddr), bytes(4), bytes(4), bytes(4),
    mac, bytes(64), bytes(128)) + b"\x63\x82\x53\x63" + opts
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, b"eth0")
s.bind(("", 68))
s.settimeout(3)
s.sendto(pkt, (dest, 67))
names = {2: "offer", 5: "ack", 6: "nak"}
try:
    while True:
        data = s.recv(2048)
        if struct.unpack("!I", data[4:8])[0] != xid:
            continue
        o = data[240:]
        while o and o[0] != 255:
            if o[0] == 53:
                print(names.get(o[2], "other"))
                sys.exit(0)
            o = o[2 + o[1]:] if o[0] else o[1:]
except socket.timeout:
    print("none")
