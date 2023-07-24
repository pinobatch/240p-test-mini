#!/usr/bin/env python3
"""
Character encoding for 144p Test Suite
"""
import codecs

# The first 96 glyphs in the font correspond to the 96 printable code
# points of the Basic Latin (ASCII) block, U+0020 through U+007F.
# The rest are as follows, beginning at 0x80.
name = 'cp144p'
extra_codepoints = [
    # mammoth, unknown, copyright, double-struck X
    0x1F9A3, 0xFFFE, 0x00A9, 0x1D54F,
    # right arrow, left arrow, up arrow, down arrow
    0x2192, 0x2190, 0x2191, 0x2193
]

# Codecs API boilerplate ############################################

### Codec APIs

class Codec(codecs.Codec):

    def encode(self,input,errors='strict'):
        return codecs.charmap_encode(input,errors,encoding_table)

    def decode(self,input,errors='strict'):
        return codecs.charmap_decode(input,errors,decoding_table)

class IncrementalEncoder(codecs.IncrementalEncoder):
    def encode(self, input, final=False):
        return codecs.charmap_encode(input,self.errors,encoding_table)[0]

class IncrementalDecoder(codecs.IncrementalDecoder):
    def decode(self, input, final=False):
        return codecs.charmap_decode(input,self.errors,decoding_table)[0]

class StreamWriter(Codec,codecs.StreamWriter):
    pass

class StreamReader(Codec,codecs.StreamReader):
    pass

### encodings module API

def getregentry():
    return codecs.CodecInfo(
        name=name,
        encode=Codec().encode,
        decode=Codec().decode,
        incrementalencoder=IncrementalEncoder,
        incrementaldecoder=IncrementalDecoder,
        streamreader=StreamReader,
        streamwriter=StreamWriter,
    )

def register():
    ci = getregentry()
    def lookup(encoding):
        if encoding == name:
            return ci
    codecs.register(lookup)

# End boilerplate ###################################################

### Translate the decoding

decoding_table = list(range(128))
decoding_table[24:32] = extra_codepoints
decoding_table.extend([0xFFFE] * (256 - len(decoding_table)))
decoding_table = ''.join(chr(x) for x in decoding_table)
encoding_table=codecs.charmap_build(decoding_table)
register()

# Transitional API

def decode_240ptxt(blo, errors='strict'):
    return str(blo, name, errors)

def encode_240ptxt(s, errors='strict'):
    return bytes(s, name, errors)

### Testing

def main():
    s = "HELLO\u00A9\U0001F426"
    b = s.encode(name)
    print(s)
    print(b.hex())

if __name__=='__main__':
    main()
