#!/bin/sh

LOGGER="logger -s -t drop_caches.sh"
$LOGGER Dropping caches.

echo 3 > /proc/sys/vm/drop_caches
