#!/usr/bin/env python3
"""
Pitch table generator
2020 Damian Yerrick
No rights reserved
"""

print('section "pitch_table",ROM0,align[1]')
print("pitch_table::")
period = 131072.0 / 65.625
for i in range(73):
    print(" dw %d" % round(2048 - period))
    period = period / 1.059463094
