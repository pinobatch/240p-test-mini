#!/bin/sh
# find the most common calls in the codebase
set -e

# Normalize whitespace
grep -h '\scall\s' src/*.z80 | awk '{$1=$1};1' | sort | uniq -c | sort -nr | head -n10

# then to find all locations of a call, do something like
# grep -C3 set_bgp src/*.z80

# also things called once (for turning into a macro)
grep -h '\scall\s' src/*.z80 | awk '{$1=$1};1' | sort | uniq -c | sort -n | head -n10
