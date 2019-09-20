#!/bin/sh
# Script to count calls to each subroutine
set -e
grep -h "call " src/*.z80 | awk '{$1=$1};1' | sort | uniq -c | sort -nr | head -n10
