# ffmuc-ebpf-clat

An eBPF-based CLAT (Customer-side transLATor) implementation for Gluon routers, providing IPv4-to-IPv6 translation using traffic control (TC) hooks.

## Overview

This package implements RFC 6145-compliant IPv4-to-IPv6 translation using eBPF programs attached to network interfaces via TC (Traffic Control). It translates incoming IPv4 packets to IPv6 by embedding IPv4 addresses into configurable IPv6 prefixes, and translates incoming IPv6 packets back.

## Features

- **eBPF-based translation**: High-performance packet translation using kernel eBPF programs
- **TC hook integration**: Attaches to network interface ingress for packet processing
- **RFC 6145 compliance**: Follows standard IPv4-to-IPv6 translation rules
- **Configurable prefixes**: Supports custom local and remote IPv6 prefixes
- **Fragment handling**: Detects and skips fragmented packets (not yet translated)

## Configuration

The translator uses two IPv6 prefixes (need to be specified without `/<size>` suffix in the arguments!):
- **Local Prefix**: e.g. `2001:db8:ff00:1:0:64::/96`
- **Remote Prefix**: e.g. `64:ff9b::/96` (well-known prefix)

IPv4 addresses are embedded in the last 32 bits of these prefixes.

## Usage

```bash
# Start CLAT on interface with index 2, using local prefix 2001:db8:ed0:6::/96 and remote prefix 64:ff9b::/96
ffmuc-ebpf-clat 2 2001:db8:ff00:1:: 64:ff9b::

# Monitor translation activity
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

## Dependencies

- `libbpf`: BPF library for userspace programs
- `bpftool` v7.5 or later: BPF program compilation and management
- Kernel with eBPF and TC support

## Build Requirements

- Clang 20 or higher with BPF target support
- Linux kernel headers
- libbpf development packages

## Limitations

- Currently only handles non-fragmented IPv4 packets
- Downstream (IPv4-to-IPv6) translation only
- Requires root privileges for TC operations
- No handling of packets with local source/destination yet
