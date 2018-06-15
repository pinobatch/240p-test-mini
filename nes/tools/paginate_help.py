#!/usr/bin/env python3
import json, sys, os
from vwfbuild import ca65_bytearray

# Find common tools
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)
from parsepages import lines_to_docs

# Character encoding ################################################

decode_240ptxt_table = {
    128: '\u00A9',  # copyright
    129: '\U0001F426',  # bird
    132: '\u2191',  # up
    133: '\u2193',  # down
    134: '\u2190',  # left
    135: '\u2192',  # right
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

def ca65_escape_bytes(blo):
    """Encode an iterable of ints in 0-255, mostly ASCII, for ca65 .byte statement"""
    runs = []
    for c in blo:
        if 32 <= c <= 126 and c != 34:
            if runs and isinstance(runs[-1], bytearray):
                runs[-1].append(c)
            else:
                runs.append(bytearray([c]))
        else:
            runs.append(c)
    return ','.join('"%s"' % r.decode('ascii')
                    if isinstance(r, bytearray)
                    else '%d' % r
                    for r in runs)

def render_help(docs):
    lines = ["""
; Help data generated with paginate_help.py - do not edit
.export helptitles_hi, helptitles_lo
.export helppages_hi, helppages_lo, help_cumul_pages
.exportzp HELP_NUM_PAGES, HELP_NUM_SECTS, HELP_BANK

.segment "HELPDATA"
HELP_BANK = <.bank(*)
"""]
    lines.extend('.exportzp helpsect_%s' % (doc[1])
                 for i, doc in enumerate(docs))
    lines.extend('helpsect_%s = %d' % (doc[1], i)
                 for i, doc in enumerate(docs))
    lines.append('helptitles_hi:')
    lines.extend('  .byte >helptitle_%s' % doc[1] for doc in docs)
    lines.append('helptitles_lo:')
    lines.extend('  .byte <helptitle_%s' % doc[1] for doc in docs)
    lines.extend('helptitle_%s: .byte %s,0'
                 % (doc[1], ca65_escape_bytes(encode_240ptxt(doc[0])))
                 for doc in docs)

    cumul_pages = [0]
    pagenum = 0
    for doc in docs:
        for page in doc[-1]:
            lines.append("helppage_%03d:" % pagenum)
            page = [bytearray(encode_240ptxt(line)) for line in page]
            for i in range(len(page) - 1):
                page[i].append(10)  # newline
            page[-1].append(0)
            lines.extend("  .byte %s" % ca65_escape_bytes(line)
                         for line in page)
            pagenum += 1
        assert pagenum == cumul_pages[-1] + len(doc[-1])
        cumul_pages.append(pagenum)
    lines.append('help_cumul_pages:')
    lines.append(ca65_bytearray(cumul_pages))
    lines.append('HELP_NUM_PAGES = %d' % cumul_pages[-1])
    lines.append('HELP_NUM_SECTS = %d' % len(docs))
    lines.append('helppages_hi:')
    lines.extend('  .byte >helppage_%03d' % i for i in range(cumul_pages[-1]))
    lines.append('helppages_lo:')
    lines.extend('  .byte <helppage_%03d' % i for i in range(cumul_pages[-1]))

    return "\n".join(lines)

def main(argv=None):
    argv = argv or sys.argv
    if len(argv) > 1 and argv[1] == '--help':
        print("usage: paginate_help.py INFILE.txt")
        return
    if len(argv) != 2:
        print("paginate_help.py: wrong number of arguments; try paginate_help.py --help")
        sys.exit(1)

    filename = argv[1]
    with open(filename, 'r', encoding="utf-8") as infp:
        lines = [line.rstrip() for line in infp]
    docs = lines_to_docs(filename, lines, maxpagelen=20)
    print(render_help(docs))

if __name__=='__main__':
##    main(['paginate_help.py', '../src/helppages.txt'])
    main()
