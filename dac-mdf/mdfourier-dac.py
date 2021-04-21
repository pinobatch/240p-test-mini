#!/usr/bin/env python3
"""
Signal for testing DAC-into-ADC

Copyright 2020 Damian Yerrick
license: zlib

The sync sequences run at 75 fps, the sector rate of Compact Disc
Digital Audio, not the 60 Hz typical of Japanese and North American
video game consoles.

 1.0 s  sync sequence (1/3 s silent, 1/3 s 8K sines on a frame off a
        frame, 1/3 s silent)
10.0 s  sine sweep from 20 Hz to 20480 Hz at 2 seconds per octave,
        time-reversed on right
 0.4 s  padding
10.0 s  1/8 pulse sweep from 20 Hz to 20480 Hz at 2 seconds per octave,
        time-reversed on right
 0.4 s  padding
 4.0 s  white noise using 15-bit LFSR
 0.4 s  padding
 4.0 s  pink noise using Voss-McCartney algorithm
 1.2 s  padding
 4.0 s  50% pulse fading from full scale to nothing, with amplitude as
        quadratic function of time
 1.0 s  sync sequence

At higher (96 kHz and 192 kHz) sample rates, the sine and pulse sweeps
run a few seconds longer to cover all octaves.

"""
import wave
from math import pi
import numpy as np
tau = 2 * pi

# This frame rate evenly divides into 44100, which produces 588-sample
# sectors, and 48000, which produces 640-sample sectors.
fps = 75

# 8192 means -12 dBFS
reflevel = 8192


def fullprint(*args, **kwargs):
    """Print an ndarray without truncation.

Use when troubleshooting signal generation

Via https://stackoverflow.com/a/24542498/2738262"""
    from pprint import pprint
    opt = np.get_printoptions()
    np.set_printoptions(threshold=np.inf)
    pprint(*args, **kwargs)
    np.set_printoptions(**opt)

def get_syncpulse(rate):
    assert fps % 3 == 0

    # 1/3 s silence, 1/3 s pulses
    silence333 = np.zeros(rate // 3, dtype=np.int16)
    framesilence = np.zeros(rate // fps, dtype=np.int16)
    pulse_t = np.linspace(0, 8000 * tau / fps,
                          num=rate//fps, endpoint=False)
    # Though astype() makes a copy, using dtype= will usually fail with
    # TypeError: No loop matching the specified signature and casting
    # was found for ufunc rint
    pulse = np.rint(np.sin(pulse_t) * reflevel).astype(np.int16)
    pulses = list((pulse, framesilence) * (fps // 6 + 1))[:fps // 3]

    # Put padding on each side
    pulses.insert(0, silence333)
    pulses.append(silence333)
    return np.concatenate(pulses)

def nonbl_saw_sweep(rate):
    """Generate a non-bandlimited saw sweep."""
    baseafreq = 20.0 / rate
    noctaves = int((1/baseafreq) // 1).bit_length() - 2
    out = []
    lastendphase = 0
    for octave in range(noctaves):
        afreq = np.geomspace(baseafreq, baseafreq * 2,
                             num=rate * 2, endpoint=False)
        phase = np.cumsum(afreq) + lastendphase
        phase -= np.floor(phase)
        out.append(phase)
        lastendphase = phase[-1]
        baseafreq *= 2.0
    return np.concatenate(out)

def sine_sweep(phasebase):
    # sweep from 20 to 20480 Hz at 0.5 octave per second
    return np.rint(np.sin(phasebase * tau) * reflevel).astype(np.int16)

BLEP_COUNT = 64
BLEP_LENGTH = 32

def make_filterbank():
    """Produce bandlimited Heaviside steps delayed by 0/64 to 63/64 samples."""
    ctimesl = BLEP_COUNT * BLEP_LENGTH
    npcat = np.concatenate((np.zeros(ctimesl), np.ones(ctimesl)))
    fnpcat = np.fft.rfft(npcat)
    fnpcat[BLEP_LENGTH:] *= 0
    fnpcat[BLEP_LENGTH - 1] *= .5
    inpcat = np.fft.irfft(fnpcat, npcat.shape[0])[ctimesl//2:3*ctimesl//2]
    fbank = inpcat.reshape((BLEP_LENGTH, BLEP_COUNT)).transpose()
    return fbank[::-1, :]

def blep_pulse_sweep(phasebase):
    fbank = make_filterbank()
##    phasebase = phasebase[rate * 10:rate * 12]  # DEBUG for shorter

    transitions = []
    for dphase, stepht in ((0, 1), (0.125, -1)):
        phase = phasebase + dphase
        phase -= np.floor(phase)

        # Find at what fractional samples to insert a windowed sinc
        # drop_t is sample indices at which the phase wraps around, and
        # delayamts is by what fraction of a sample the wrap is delayed.
        dphase = np.diff(phase, append=0)
        drop_t = np.nonzero(dphase < 0)[0]
        delayamts = (1 - phase[drop_t])/(1 + dphase[drop_t])
        delayamts = np.floor(delayamts * fbank.shape[0])
        
        newstack = np.vstack((drop_t, delayamts, np.full(drop_t.shape, stepht)))
        transitions.append(newstack)

    transitions = np.concatenate(transitions, 1)
    ordering = np.argsort(transitions[0])
    transitions = transitions[:,ordering]

    out = np.zeros(phasebase.shape)
    bias_t, bias_level = 0, 1/7
    for t, t_sub, delta in transitions.T:
        t = int(t)
        t_sub = min(int(t_sub), fbank.shape[0] - 1)
        step = fbank[int(t_sub)] * delta
        new_bias_t = min(out.shape[0], t + len(step))
        out[bias_t:new_bias_t] += bias_level
        out[t:new_bias_t] += step[:new_bias_t - t]
        bias_t, bias_level = new_bias_t, bias_level + delta

    return np.rint(out * reflevel).astype(np.int16)

def get_lfsr(length):
    """Generate noise samples from a 15-bit linear feedback shift register.

Alternate between +reflevel and -reflevel using the same algorithm
as late 1970s-early 1980s programmable sound generators.
"""
    lfsr_state = 0x0C90
    out = np.zeros(length, dtype=np.int16)
    for i in range(length):
        lfsr_state <<= 1
        if lfsr_state >= 0x8000:
            out[i] = reflevel
            lfsr_state ^= 0x8003
        else:
            out[i] = -reflevel
    return out

def get_pink(lfsr):
    """Given white noise, generate pink noise with Voss-McCartney algorithm"""
    out = np.zeros(len(lfsr), dtype=np.int16)
    pinkchannels = [0]*10
    level = sum(pinkchannels)
    for i, (pk, wh) in enumerate(zip(lfsr, np.flip(lfsr))):
        channel = min((i ^ (i - 1)).bit_length() - 1, len(pinkchannels) - 1)
        level -= pinkchannels[channel]
        pinkchannels[channel] = pk
        level += pk
        out[i] = (level + wh // 2) // 8
    return out

def get_fade(length, halfperiod):
    fade = np.linspace(1, 0, length)
    fade = fade * fade
    square = np.full((halfperiod,), 32767)
    square = np.concatenate((square, -square))
    nreps = -(-fade.shape[0] // square.shape[0])
    square = np.tile(square, nreps)[:fade.shape[0]]
    return (square * fade).astype(np.int16)

def wavewrite(file, data, freq):
    # We have time along axis 0 and channels along axis 1.
    # RIFF WAVE wants the data sample-interleaved and little-endian
    # signed 16-bit PCM.  If axis 0 is time and 1 is channel,
    # is "fortran" order.
    nframes = data.shape[-1]
    nchannels = data.shape[0] if len(data.shape) > 1 else 1
    data = np.asfortranarray(data, np.dtype("<i2")).tobytes("F")
    with wave.open(file, "wb") as outfp:
        outfp.setnchannels(nchannels)
        outfp.setsampwidth(2)
        outfp.setframerate(freq)
        outfp.setnframes(nframes)
        outfp.writeframes(data)

def make_test_signals(rate):
    print("generating sync pulse for %d Hz" % rate)
    syncpulse = get_syncpulse(rate)
    silence400 = np.zeros(rate * 4 // 10, dtype=np.int16)
    print("sine sweep")
    sweep_phaseseq = nonbl_saw_sweep(rate)
    sine_sweep_data = sine_sweep(sweep_phaseseq)
    print("band-limited pulse sweep")
    pulse_sweep_data = blep_pulse_sweep(sweep_phaseseq)
    sweep_phaseseq = None

    print("noise")
    lfsr_data = get_lfsr(4*rate)
    pink_data = get_pink(lfsr_data)
    print("fade")
    fade_data = get_fade(4*rate, int(round(rate/600)))
    print("cat")

    outdataL = np.concatenate((
        syncpulse,
        sine_sweep_data,
        silence400,
        pulse_sweep_data,
        silence400,
        lfsr_data,
        silence400,
        pink_data,
        silence400,
        silence400,
        silence400,
        fade_data,
        syncpulse
    ))
    outdataR = np.concatenate((
        syncpulse,
        np.flip(sine_sweep_data),
        silence400,
        np.flip(pulse_sweep_data),
        silence400,
        lfsr_data,
        silence400,
        pink_data,
        silence400,
        silence400,
        silence400,
        fade_data,
        syncpulse
    ))
    return np.vstack((outdataL, outdataR))

def main():
    for rate in (44100, 48000, 96000):
        outdata = make_test_signals(rate)
        filename = "mdfourier-dac-%d.wav" % rate
        print("Writing", filename)
        wavewrite(filename, outdata, rate)
        outdata = None

if __name__=='__main__':
    main()
