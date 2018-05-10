"""
Character encoding for 144p Test Suite
"""
# Character encoding ################################################

decode_240ptxt_table = {
    130: '\u00A9',  # copyright
    131: '\U0001F426',  # bird
    132: '\u2192',  # right
    133: '\u2190',  # left
    134: '\u2191',  # up
    135: '\u2193',  # down
}


def UnicodeEncodeErrorKW(encoding=None, object=None,
                         start=None, end=None, reason=None):
    """Convenience factory for UnicodeEncodeError that accepts keyword arguments.

encoding -- string naming the character encoding
object -- the (Unicode) string being encoded
start, end -- indices denoting the slice containing errors
reason -- additional message

help(UnicodeEncodeError) lists the data attributes of an exception,
but they're sorted alphabetically for the convenience of readers,
not in the order of their corresponding positional arguments to
the exception's constructor.  Trying to use these attributes as
keywords in the constructor when raising UnicodeEncodeError instead
raises a different exception:

    TypeError: UnicodeEncodeError does not take keyword arguments

The docstrings of UnicodeEncodeError and UnicodeEncodeError.__init__
are hopelessly uninformative.

After a half hour of searching the web using Google, I finally found
the correct positional argument order on
https://coderwall.com/p/stzy9w/raising-unicodeencodeerror-and-unicodedecodeerror-manually-for-testing-purposes

"""
    return UnicodeEncodeError(encoding, object, start, end, reason)

def UnicodeDecodeErrorKW(encoding=None, object=None,
                         start=None, end=None, reason=None):
    """Convenience factory for UnicodeEncodeError that accepts keyword arguments.

See help(UnicodeEncodeErrorKW) for signature.
"""
    return UnicodeDecodeError(encoding, object, start, end, reason)

def decode_240ptxt(blo, errors='strict'):
    out, firsterr, lasterr = [], None, 0
    for i, bvalue in enumerate(blo):
        # values 0-127 are same as ascii
        if bvalue < 128:
            out.append(chr(bvalue))
            continue
        try:
            out.append(decode_240ptxt_table[bvalue])
        except KeyError:
            lasterr = i
            if firsterr is None: firsterr = i
            if errors != 'ignore': out.append('\uFFFD')
    if firsterr is not None and errors == 'strict':
        raise UnicodeDecodeErrorKW(
            encoding='240ptxt',
            reason='no code point for 0x%02x' % blo[firsterr],
            object=blo, start=firsterr, end=lasterr + 1
        )
    return ''.join(out)

encode_240ptxt_table = dict((v, k) for k, v in decode_240ptxt_table.items())

def encode_240ptxt(s, errors='strict'):
    out, firsterr, lasterr = bytearray(), None, 0
    for i, ch in enumerate(s):
        # values 0-127 are same as ascii
        if ch < '\u0080':
            out.append(ord(ch))
            continue
        try:
            out.append(encode_240ptxt_table[ch])
        except KeyError:
            lasterr = i
            if firsterr is not None: firsterr = i
            if errors != 'ignore': out.append('?')
    if firsterr is not None and errors == 'strict':
        raise UnicodeEncodeErrorKW(
            encoding='240ptxt',
            reason='no encoding for U+%04x' % ord(s[firsterr]),
            object=s, start=firsterr, end=lasterr + 1
        )
    return bytes(out)

