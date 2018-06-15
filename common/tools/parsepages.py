#!/usr/bin/env python3
"""
Converting lines to documents
"""
import re

nonalnumRE = re.compile("[^0-9a-zA-Z]+")

def lines_to_docs(filename, lines, wrap=None, maxpagelen=16):
    """Convert a list of lines to a list of documents.

filename -- source of list of lines for use in error messages
lines -- a list of lines of the following form
    "== section title ==": start of document
    "----": page separator
    Other: text on page.  Leading, trailing, and consecutive
    blank lines will be removed.
wrap -- a function performing word wrap on long lines (optional)
maxpagelen -- raise an exception if text lines per page exceeds this
"""
    # docs[docnum] = (title, labelname, docpages)
    # docpages[pagenum][linenum] = line text
    docs, secttitles = [], {}
    for linenum, line in enumerate(lines):
        line = line.rstrip()
        if line.startswith('==') and line.endswith('=='):
            # New section
            secttitle = line.strip('=').strip()
            normtitle = nonalnumRE.sub('_', secttitle.lower()).strip('_')
            try:
                oldsection = secttitles[normtitle]
            except KeyError:
                pass
            else:
                oldsecttitle, oldlinenum = oldsection
                raise ValueError("%s:%d: %s was already defined on line %d"
                                 % (filename, linenum + 1,
                                    oldsecttitle, oldlinenum))
            secttitles[normtitle] = (secttitle, linenum)
            docs.append((secttitle, normtitle, [[]]))
            continue
        docpages = docs[-1][-1] if docs else None
        doclastpage = docpages[-1] if docpages else None
        
        line_rstrip = line.rstrip()
        if line_rstrip == '':
            # Blank line; append only if following a nonblank line
            if doclastpage and doclastpage[-1]:
                doclastpage.append('')
            continue
        if doclastpage is None:
            raise IndexError("%s:%d: nonblank line with no open document"
                             % (filename, linenum + 1))
        if line.startswith('----') and line.rstrip('-') == '':
            # Page break
            if doclastpage:
                docpages.append([])
            continue

        # Ordinary text
        doclastpage.extend(wrap(line_rstrip) if wrap else [line_rstrip])
        if len(doclastpage) > maxpagelen:
            raise IndexError("%s:%d: exceeds page length of %d lines"
                             % (filename, linenum + 1, maxpagelen))

    for doc in docs:
        pages = doc[-1]

        # Remove trailing blank lines
        for page in pages:
            while page and not page[-1]: del page[-1]

        # Remove blank pages
        for i in range(len(pages) - 1, -1, -1):
            if not pages[i]: del pages[i]

    # Remove blank docs entirely
    for i in range(len(docs) - 1, -1, -1):
        if not docs[i][-1]:
            del docs[i]

    return docs
