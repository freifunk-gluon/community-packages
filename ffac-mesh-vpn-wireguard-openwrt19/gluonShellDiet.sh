#!/bin/sh

# This script requires a file as argument in which it will remove all comment lines that start with a hash '#'

sed -i '/^\s*\#[^!].*/d; /^\s*\#$/d' $1
