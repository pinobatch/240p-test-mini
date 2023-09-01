#!/usr/bin/env python3
"""
savescan.py: Static Automatic Variable Earmarker
local variable allocation for RGBASM

Copyright 2023 Damian Yerrick

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""
"""
Static Automatic Variable Earmarker is a tool to allocate local
variables for subroutines in programs written in Game Boy
assembly language.  It helps you save time over automatic allocation
in stack frames and save memory over fully static allocation.

Programming languages give a function's local variables either an
"automatic" lifetime or a "static" lifetime.  The default in C and
C++ is automatic, lasting until a function returns.  An automatic
variable is usually allocated in a stack frame and then deallocated
at return.  By contrast, a static variable persists with the same
address until the program ends, like a global variable.

Vintage processors, such as 8080 family, are slow to read and
write variables in a stack frame.  Many programs for such machines
declare variables static for speed at the cost of wasting memory for
variables that never live at the same time.  Fortunately, one can do
better.  The lifetime of a non-recursive function's variables won't
overlap itself.  Nor will the lifetimes of different functions'
variables overlap each other unless one calls the other directly
or indirectly.  Determining lack of overlap at build time allows
placing each function's automatic variables at a fixed address.
This matches 8080 addressing better than a stack frame.

Though some commercial compilers offer this allocation paradigm,
there appears to be no widely accepted term for it in the literature:

- Microchip calls the technique "compiled stack", a term inherited
  from HI-TECH PICC.
  <https://stackoverflow.com/a/58408272/2738262>
  <http://ww1.microchip.com/downloads/en/DeviceDoc/50002053G.pdf>
- Dwedit calls it "stack flattening".
  <https://forums.nesdev.org/viewtopic.php?p=249782#p249782>
- Oziphantom calls it "window allocator".
  <https://forums.nesdev.org/viewtopic.php?p=249801#p249801>

In your programs, define `local`, `calls`, `tailcalls`, and
`jumptable` macros that do nothing, and define `fallthrough`
that asserts that its argument's address is the program counter.
SAVE uses these macros to infer the call graph structure:

- `local hVarname[, size]`  
  Allocates a local variable with a given size.  Must be a decimal
  or hex literal.
- `calls otherFunc`  
  Mark this function as a caller of `otherFunc`.  The `call`
  instruction also does this.
- `tailcalls otherFunc`  
  Mark this function as a tail caller of `otherFunc`.  The `jp` and
  `jr` instructions also do this.
- `fallthrough otherFunc`  
  Mark this function as an inline tail caller of `otherFunc`.
  (An "inline tail call" happens when execution falls off the end
  of one function into another.)  Also helps express intent during
  refactoring.  If this is missing, SAVE may emit a diagnostic.
- `jumptable`  
  Treats labels in `dw` arguments in this scope as tail callees.
  The subroutine reading this table should `tailcalls` the table
  as well.

For each function, SAVE calculates a start and end offset.

- A function's start offset is the largest end offset of its callees.
- A function's end offset is its start offset plus the size of its
  local variables, but no less than the largest end offset of its
  tail callees.

SAVE writes a UNION containing each function's offsets to an assembly
language file.  Assemble it with RGBASM and link it into your 

One limit is that SAVE cannot see macros defined in an include file.
SAVE does not follow `INCLUDE` directives because RGBDS searches for
them relative to the current working directory, not the directory
containing the including source file.

Implementation notes
--------------------

In ca65, an exported constant can be the value of an arbitrary
expression.  An assembly file can import callees' end offsets and
use those to calculate start and end offsets of the caller.  This
produces a complex relocation expression for the linker to resolve.

In RGBASM, by contrast, an exported constant's value must be known
at assembly time, defined through an expression ultimately made of
literal values.  An expression depending on an imported value can be
defined (as a text macro) but not exported.  So instead, this program
(savescan.py) scans all source code files, builds a call graph, and
calculates all functions' start and end offsets.  Though it needs
to be re-run whenever any source file changes, this still completes
faster than (say) link-time optimization (LTO) of a C++ program.
"""

import os, sys, argparse
from collections import defaultdict
from itertools import chain

# rgbasm parsing ####################################################

nonjump_opcodes = {
    'ld', 'add', 'adc', 'sub', 'sbc', 'xor', 'or', 'and', 'cp',
    'rlca', 'rla', 'rrca', 'rra', 'rlc', 'rl', 'rrc', 'rr',
    'swap', 'srl', 'sra', 'sla', 'bit', 'set', 'res',
    'ccf', 'scf', 'cpl', 'daa', 'di', 'ei', 'ret', 'reti',
    'dec', 'inc', 'ret', 'ldh', 'push', 'pop', 'nop', 'halt', 'stop',
}

def rgbint(s):
    if s.startswith('$'): return int(s[1:], 16)
    if s.startswith('%'): return int(s[1:], 2)
    return int(s[1:], 10)

class AsmFile(object):
    def __init__(self, lines=None):
        self.toplabel = self.jumptable_contents = None
        self.last_was_jump = False
        self.in_macro = self.in_jumptable = self.section_is_bss = False
        self.unknown_opcodes = set()
        self.exports = {}
        self.calls = defaultdict(set)
        self.tailcalls = defaultdict(set)
        self.linenum = 0
        self.warnings = []
        self.is_fixlabel = None
        self.locals_size = {}  # {funcname: [(varname, size), ...], ...}
        if lines: self.extend(lines)

    def extend(self, lines):
        for line in lines: self.append(line)

    def append(self, line):
        self.linenum += 1
        line = line.strip().split(";", 1)[0]

        # Process labels
        label, line, is_exported = self.label_split(line)
        if label and not self.in_macro: self.add_label(label, is_exported)
        if not line: return

        # Handle some directives
        opcode, operands = self.opcode_split(line)
        if opcode == 'section':
            self.add_section(operands)
            return
        if opcode in ('export', 'global'):
            self.add_exports(operands)
            return
        if opcode == 'endm':
            if not self.in_macro:
                raise ValueError("endm without macro")
            self.in_macro = False
            return
        if opcode == 'macro':
            if self.in_macro:
                raise ValueError("nested macro not supported")
            self.in_macro = True
            self.unknown_opcodes.add(operands[0])
            return
        if opcode == 'jumptable':
            if self.toplabel is None:
                raise ValueError("jumptable without top-level label")
            self.in_jumptable = True
            return

        # Remaining opcodes add code if and only if they're
        # not inside a macro.
        if self.in_macro: return

        if opcode == 'local':
            self.add_local(operands)
            return

        if opcode == 'dw':
            if self.in_macro: return
            if self.toplabel is None:
                raise ValueError("dw without top-level label")
            self.add_jumptable_entries(operands)
            return

        # Determine whether line is unconditional jump
        preserves_jump = self.opcode_preserves_jump_always(opcode, operands)
        is_jump = self.opcode_is_jump_always(opcode, operands)

        if self.opcode_can_jump(opcode):
            _, target = self.condition_split(operands)
            self.add_tailcall(self.toplabel, target)
        elif self.opcode_can_call(opcode):
            _, target = self.condition_split(operands)
            self.add_call(self.toplabel, target)
        elif opcode not in nonjump_opcodes and not preserves_jump:
            # Treat unknown opcodes as probably data macros defined
            # in an include file.  (The tool skips include files
            # because unlike in C and ca65, RGBASM include paths
            # are relative to the CWD, and the CWD is unknown.)
            if opcode not in self.unknown_opcodes:
                self.unknown_opcodes.add(opcode)
                self.warn("unknown instruction %s" % (opcode,))
            preserves_jump = True

        if not preserves_jump: self.last_was_jump = is_jump

    def add_label(self, label, is_exported=False):
        if label == '':
            self.warn("%s: disregarding anonymous label" % (self.toplabel,))
            return

        if label.startswith('.'):
            if self.toplabel is None:
                raise ValueError("no top-level label for local label %s"
                                 % (label,))
            label = self.toplabel + label
        else:
            # since https://github.com/gbdev/rgbds/pull/1159
            # a local label may appear outside the scope of the
            # corresponding global label, for an "in medias res"
            # routine like stpcpy
            label = label.split(".")[0]
            if (self.toplabel is not None and not self.section_is_bss
                and not self.last_was_jump and self.last_was_jump is not None):
                if self.is_fixlabel:
                    self.warn("fixed address label %s falls through to %s"
                              % (self.toplabel, label))
                    self.add_tailcall(self.toplabel, label)
                    self.is_fixlabel = False
                elif self.toplabel != label:
                    self.warn("%s may fall through to %s"
                              % (self.toplabel, label))
            self.flush_jumptable()
            self.toplabel = label
            self.last_was_jump = None

        if is_exported: self.add_exports([label])

    def warn(self, msg):
        self.warnings.append((self.linenum, msg))

    def add_exports(self, new_exports):
        for label in new_exports:
            self.exports[label] = self.linenum

    def end_section(self):
        """Perform tasks at the end of a section.

Make sure to call this after appending all lines from a file.
Otherwise, a jump table that occurs last may not be found.
"""
        if (self.toplabel is not None and not self.section_is_bss
            and not self.last_was_jump and self.last_was_jump is not None):
            self.warn("%s may fall off end of section" % (self.toplabel,))
        self.flush_jumptable()
        self.toplabel = None
        self.last_was_jump = True
        self.is_fixlabel = False

    def add_section(self, operands):
        if len(operands) < 2:
            raise ValueError("section %s has no memory area!")
        self.end_section()

        # Determine whether this is a RAM section.  RAM sections
        # don't issue fallthrough warnings.
        op1split = operands[1].split('[', 1)
        memory_area = op1split[0].strip().upper()
        ramsection_names = ("WRAM", "SRAM", "HRAM")
        self.section_is_bss = memory_area.startswith(ramsection_names)

        # Try to assign fixed memory addresses, so as to find things like
        # RST $00, $08, $10, ..., $38, and entry point at $100
        fixaddr = op1split[1].rstrip(']').strip() if len(op1split) > 1 else ''
        if fixaddr and memory_area == "ROM0":
            fixlabel = self.canonicalize_call_target(fixaddr)
            self.add_label(fixlabel)
            self.add_exports([fixlabel])
            self.is_fixlabel = True

    def flush_jumptable(self):
        """Have the current toplabel tailcall all jumptable_contents members.

Call this before setting or clearing a toplabel.
"""
        if self.toplabel is not None and self.in_jumptable:
            for row in self.jumptable_contents:
                self.add_tailcall(self.toplabel, row)
        self.in_jumptable, self.jumptable_contents = False, set()

    def add_local(self, operands):
        varname = operands[0]
        if self.toplabel is None:
            raise ValueError("local %s without top-level label" % (varname,))
        func_locals = self.locals_size.setdefault(self.toplabel, [])
        prev_sizes = [row[1] for row in func_locals if row[0] == varname]
        if prev_sizes:
            raise ValueError("redefined local %s; previous size was %d"
                             % (varname, prev_sizes[0]))
        size = operands[1] if len(operands) > 1 else ''
        func_locals.append((varname, int(size or '1')))

    def add_call(self, fromlabel, tolabel):
        # disregard calls within function
        if tolabel.startswith('.'): return

        self.calls[fromlabel].add(self.canonicalize_call_target(tolabel))

    def add_tailcall(self, fromlabel, tolabel):
        # disregard jumps within function
        if tolabel.startswith((':', '.')): return
        # disregard whole-function loops
        if tolabel == fromlabel: return
        # jp hl is handled by "tailcalls some_table"
        if tolabel.lower() == 'hl': return

        self.tailcalls[fromlabel].add(self.canonicalize_call_target(tolabel))

    def add_jumptable_entries(self, operands):
        self.jumptable_contents.update(operands)

    @staticmethod
    def label_split(line):
        """Split a line into label and remainder parts

Return (label part, remainder part, True if exported)
"""
        colonsplit = line.split(':', 1)
        if '"' in colonsplit[0]: return None, line, False  # ld a, ":"
        if len(colonsplit) == 1 and line.startswith('.'):
            # local labels can be terminated by whitespace instead of colon
            colonsplit = line.split(None, 1)
            if len(colonsplit) < 2: return line, "", False
        if len(colonsplit) < 2: return None, line, False

        label, line = colonsplit
        is_exported = line.startswith(':')
        if is_exported: line = line[1:]
        return label.rstrip(), line.lstrip(), is_exported

    @staticmethod
    def opcode_split(line):
        """Split a line into opcode and operand parts

line must not define a label, that is, label_split must be run first

Return (opcode, [operand, ...])
"""
        first2words = line.split(None, 1)
        opcode = first2words[0].lower()
        operands = first2words[1] if len(first2words) > 1 else ''
        return opcode, [x.strip() for x in operands.split(',')]

    @staticmethod
    def opcode_preserves_jump_always(opcode, operands):
        """Return true if this line usually doesn't affect function-to-function reachability"""
        ignored_opcodes = (
            'if', 'else', 'elif', 'endc', 'def', 'include', 'incbin',
            'rept', 'endr', 'dw', 'db', 'ds', 'rsreset', 'rsset', 'assert',
            'warn', 'fail'
        )
        if opcode in ignored_opcodes: return True
        return False

    @staticmethod
    def opcode_is_jump_always(opcode, operands):
        """Return true if the following line is never reachable from this line"""
        return_opcodes = ('ret', 'reti')
        jump_opcodes = ('jp', 'jr', 'fallthrough')
        is_conditional, target = AsmFile.condition_split(operands)
        if is_conditional: return False
        if opcode in return_opcodes or opcode in jump_opcodes: return True
        return False

    @staticmethod
    def opcode_can_jump(opcode):
        return opcode in ('jp', 'jr', 'tailcalls', 'fallthrough')

    @staticmethod
    def opcode_can_call(opcode):
        return opcode in ('call', 'rst', 'calls')

    @staticmethod
    def canonicalize_call_target(target):
        """Convert numbers used as call targets to 4-digit hex and remove sub-labels.

Convert '56' and '$38' to '$0038' and 'routine.loop' to 'routine'.
""" 
        try:
            fixlabel = rgbint(target)
        except ValueError:
            # treat a call to a sub-label as a call to its top label
            s = target.split('.', 1)
            return s[0] or target
        else:
            return "$%04X" % fixlabel

    @staticmethod
    def condition_split(operands):
        condition_codes = ('c', 'nc', 'z', 'nz')
        is_conditional = (len(operands) > 0
                          and operands[0].lower() in condition_codes)
        target_operand = 1 if is_conditional else 0
        target = (operands[target_operand]
                  if len(operands) > target_operand
                  else '')
        return is_conditional, target

def load_files(filenames, verbose=False):
    """Load and parse source code files.

filenames -- iterable of things to open()
verbose -- if True, print exception stack traces to stderr

Return a 2-tuple (files, all_errors, all_warnings)
- files -- {filename: AsmFile instance, ...}
- all_errors -- [(filename, linenum, msg), ...] of exceptions
- all_warnings -- (filename, linenum, msg), ...] of warnings
"""
    if verbose:
        from traceback import print_exc

    files, all_errors, all_warnings = {}, [], []
    for filename in filenames:
        with open(filename, "r") as infp:
            result = AsmFile()
            try:
                result.extend(infp)
                result.end_section()
            except Exception as e:
                if verbose: print_exc()
                all_errors.append((filename, result.linenum, str(e)))
            else:
                files[filename] = result
            finally:
                all_warnings.extend((filename, ln, msg)
                                    for ln, msg in result.warnings)
    return files, all_errors, all_warnings

# call graph sorting and allocation #################################

def get_exports(files):
    """Find exports in a set of parsed source files.

files -- {filename: AsmFile instance, ...}

Return a 2-tuple (exports, errors)
exports -- {symbol: (filename, linenum), ...}
errors -- [(filename, linenum, msg), ...]
"""
    all_exports, all_errors = {}, []
    for filename, result in files.items():
        for symbol, linenum in result.exports.items():
            try:
                old_filename, old_linenum = all_exports[symbol]
            except KeyError:
                all_exports[symbol] = filename, linenum
            else:
                all_errors.append((filename, linenum, "%s reexported" % symbol))
                all_errors.append((old_filename, old_linenum,
                                   "%s had been exported here" % symbol))
    return all_exports, all_errors

def postorder_callees(files, exports, start_label="$0100"):
    """Sort labels reachable from the start by callees first.

files: a dict {filename: AsmFile instance, ...}
exports: a dict {label: (filename, ...), ...}
start_label: the first label to call (in GB, usually $0100)

Return (toposort, itoposort)
where toposort is [(filename, label), ...]
and itoposort is its inverse {(filename, label): index into toposort, ...}
"""
    # stack is a list of stack frames to be visited
    # each stack frame is [(module, label), ...]
    stack = [[(exports[start_label][0], start_label)]]
    itoposort = {}  # {(filename, label): index, ...}
    while stack:
        stackframe = stack.pop()
        routine_key = stackframe[-1]
        filename, label = routine_key
        assert filename is not None
        if routine_key in itoposort: continue

        # Find all callees that aren't already in the toposort
        # or in the stack
        module = files[filename]
        callees = module.calls[label]
        tailcallees = module.tailcalls[label]
        new_callees = []
        for callee in chain(callees, tailcallees):
            try:
                callee_filename = exports[callee]
            except KeyError:
                callee_filename = filename
            else:
                callee_filename = callee_filename[0]
            callee_key = callee_filename, callee
            if callee_key not in itoposort and callee_key not in stackframe:
                new_callees.append(callee_key)

        # If any callee hasn't been seen, toposort all callees first
        # and come back later
        if new_callees:
            stack.append(stackframe)
            for callee in new_callees:
                new_frame = list(stackframe)
                new_frame.append(callee)
                stack.append(new_frame)
        else:
            itoposort[routine_key] = len(itoposort)

    toposort = [None] * len(itoposort)
    for symbol, index in itoposort.items():
        toposort[index] = symbol
    return toposort, itoposort

def allocate(files, exports, toposort):
    """Allocate local variables per a topological sort.

files -- {filename: module, ...} where
    module.calls is {label, ...}
    module.tailcalls is {label, ...}
    module.locals_size is {label: [(name, size), ...], ...}
exports -- {symbol: (filename, ...), ...}
toposort -- [(filename, label), ...] with callees first

Return an allocation
{(filename, label): (callee_use_end, self_use_end), ...}
"""
    func_allocation = {}
    for caller_key in toposort:
        filename, label = caller_key
        module = files[filename]
        caller_locals = module.locals_size.get(label, [])

        # find module for each callee
        callees = module.calls[label]
        tailcallees = module.tailcalls[label]
        callee_file = {}
        for callee in chain(callees, tailcallees):
            try:
                x = exports[callee]
            except KeyError:
                callee_file[callee] = filename
            else:
                callee_file[callee] = x[0]

        # Start caller's variables after the self_use_end of its callees
        # and after the callee_use_end of its tail callees
        callee_max = tailcallee_max = 0
        for callee in callees:
            callee_key = callee_file[callee], callee
            callee_uses = func_allocation[callee_key]
            callee_max = max(callee_uses[1], callee_max)
        for callee in tailcallees:
            callee_key = callee_file[callee], callee
            try:
                callee_uses = func_allocation[callee_key]
            except KeyError:
                print("warning: %s in %s tailcall loop to %s in %s"
                      % (callee_key[1], callee_key[0], label, filename),
                      file=sys.stderr)
                continue
            tailcallee_max = max(callee_uses[1], tailcallee_max)

        self_total = sum(row[1] for row in caller_locals)
        self_end = max(tailcallee_max, self_total + callee_max)
        func_allocation[caller_key] = callee_max, self_end
    return func_allocation

def format_allocation(files, allocation):
    """Format an allocation as RGBASM source code.

files -- {filename: module, ...} where
    module.locals_size is {label: [(name, size), ...], ...}
allocation -- {(filename, label): (callee_use_end, self_use_end), ...}
"""
    lines = [
        '; Generated with savescan.py - Static Automatic Variable Earmarker',
        '; for RGBASM 0.6.2 or later',
        'section "hSAVE_locals",HRAM',
        '  union',
    ]
    max_end = 0
    for func_key, (start, end) in allocation.items():
        if end <= start: continue
        module_name, label = func_key
        module = files[module_name]
        try:
            func_locals = module.locals_size[label]
        except KeyError:
            # This happens when a function has no local variables and
            # its tail callees' end has propagated to it.
            continue

        if max_end > 0: lines.append('  nextu')
        max_end = max(end, max_end)
        if start > 0: lines.append("    ds %d" % start)
        lines.extend("    %s.%s:: ds %d" % (label, varname, size)
                     for varname, size in func_locals)
    lines.append('  endu')
    lines.append('; maximum size of live local variables: %d bytes' % max_end)
    lines.append('')
    return '\n'.join(lines)

# command line ######################################################

def parse_argv(argv):
    usageMsg = "Parses RGBASM source to determine a call graph and allocate local variables."
    p = argparse.ArgumentParser(description=usageMsg)
    p.add_argument("sourcefile", nargs="+",
                   help="names of all source code files")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="print more debugging information")
    p.add_argument("-o", "--output", default="-",
                   help="write allocation to this file instead of standard output")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    result = load_files(args.sourcefile, verbose=args.verbose)
    files, all_errors, all_warnings = result
    exports, errors = get_exports(files)
    all_errors.extend(errors)
    if all_errors:
        print("\n".join(
            "%s:%d: error: %s" % row for row in all_errors
        ), file=sys.stderr)
    if all_warnings:
        print("\n".join(
            "%s:%d: warning: %s" % row for row in all_warnings
        ), file=sys.stderr)
    if all_errors:
        exit(1)
    toposort, itoposort = postorder_callees(files, exports)
    allocation = allocate(files, exports, toposort)
    tallocation = format_allocation(files, allocation)
    if args.output == '-':
        sys.stdout.write(tallocation)
    else:
        with open(args.output, "w") as outfp:
            outfp.write(tallocation)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        folder = "../src"
        args = ["./savescan.py"]
        args.extend(os.path.join(folder, file)
                    for file in sorted(os.listdir(folder))
                    if os.path.splitext(file)[1].lower()
                    in ('.z80', '.asm', '.s', '.inc'))
        main(args)
    else:
        main()
