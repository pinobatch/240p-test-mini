#!/usr/bin/env python3
import wave
from io import BytesIO
from array import array
import winsound

##ideal_freqs = [98.00, 123.47, 146.83, 196.00, 246.94, 392.00]
##ideal_periods = [185.27, 147.06, 123.66, 92.64, 73.53, 46.31]
periods = [
    [186, 1, 3],
    [148, 1, 3],
    [124, 3, 1],
    [93, 3, 1],
    [74, 3, 1],
    [47, 1, 3],
]
delaylines = [array('h', [0]) * p[0] for p in periods]
phases = array('h', [0]) * len(periods)

for i, (p, delayline) in enumerate(zip(periods, delaylines)):
    exci = 10000 if i & 1 else -10000
    exci = array('h', [exci]) * (p[0] // 8)
    delayline[:len(exci)] = exci

output = array('h', [0]) * 18157 * 2
for i in range(len(periods)):
    period, fac1, fac2 = periods[i]
    phase = phases[i]
    delayline = delaylines[i]
    
    for t in range(i * 304, len(output)):
        output[t] += delayline[phase]
        nextphase = phase + 1
        if nextphase >= period: nextphase = 0
        newsample = (fac1 * delayline[phase]
                     + fac2 * delayline[nextphase]
                     + 2) * 255 // 1024
        delayline[phase] = newsample
        phase = nextphase
    phases[i] = phase
output = bytearray((x + 0x8000) >> 8 for x in output)

print(sum(len(x) for x in delaylines), "total samples in delay lines")
with BytesIO() as outfp:
    wv = wave.open(outfp, "w")
    wv.setnchannels(1)
    wv.setsampwidth(1)
    wv.setframerate(18157)
    wv.writeframes(bytes(4000))
    wv.writeframes(output)
    wv.close()
    winsound.PlaySound(outfp.getvalue(), winsound.SND_MEMORY)
