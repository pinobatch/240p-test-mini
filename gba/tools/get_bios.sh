#!/bin/bash
# Downloader for SkyEmu distribution of Cult of GBA BIOS
# Copyright 2024 Damian Yerrick
# SPDX-License-Identifier: FSFAP
#
# Script to download and produce the file gba_bios.bin based on
# Cult of GBA BIOS <https://github.com/Cult-of-GBA/BIOS>
# which is under Expat license
set -e
curl --remote-name --referer 'https://github.com/SourMesen/Mesen2/' 'https://raw.githubusercontent.com/skylersaleh/SkyEmu/555bd384f3346b7cd3103d74d5191c3b86312157/src/gba_bios.h'
gcc -std=c11 -s -Os -o write_bios write_bios.c
./write_bios
