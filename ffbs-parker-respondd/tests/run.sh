#!/bin/sh
# Test of the FDB filter of the client count. Needs a C compiler and Linux
# headers. On another OS: docker run --rm -v "$PWD":/p -w /p gcc:14 sh tests/run.sh
set -e
cd "$(dirname "$0")"
out=$(mktemp)
trap 'rm -f "$out"' EXIT
${CC:-cc} -Wall -Werror -fsanitize=address,undefined -I../src -o "$out" fdb-test.c ../src/clients.c
"$out"
