# Draft upstream report — [`cxxfilt-stdin-nonascii`](../../BACKLOG.md#cxxfilt-stdin-nonascii)

**Status: DRAFTED, NOT FILED.** The author decided this track drafts its
upstream reports and does not post them. Nothing below has been sent to any
issue tracker. The maintainer files it.

- **Target:** `llvm/llvm-project`, new issue. Suggested labels: `tools:llvm-cxxfilt`,
  `demangling`.
- **Confirmed against trunk:** `llvm/tools/llvm-cxxfilt/llvm-cxxfilt.cpp` is
  **byte-identical** between `d28193fa1ff6` (2026-08-04, the base of
  `~/src/llvm/build-unicode-upstream`) and `upstream/main` at **`72417eb739e5`**
  (2026-09-05, fetched 2026-09-06), so the binary reproduction below is against
  today's trunk code. Reproduced on two builds: `783a9c1a5f6f`
  (base `d28193fa1ff6`, `~/src/llvm/build-unicode-upstream`, no feature flags
  passed) and `a815e6f267c1` (2026-06-13, `~/src/llvm/build-main`, pristine).
- **Existing-issue search (2026-09-06), no duplicate.** Queries against
  `repo:llvm/llvm-project` (`is:issue`, open and closed): `llvm-cxxfilt stdin`
  (8 — #83048 and #39337 read, see below; the rest unrelated),
  `cxxfilt non-ascii` (0), `IsLegalItaniumChar` (0),
  `demangle extended identifier unicode` (0), `in:title cxxfilt` (12, listed
  and read — none is this).
  **Two are worth citing and neither is a duplicate.** **#39337** (closed
  FIXED, Feb 2019) is the feature request that *introduced* the split — "We
  should consider splitting the input string on spaces before running
  llvm-cxxfilt on it" — so it is where the under-inclusive predicate came from.
  **#118705** (closed) fixed an out-of-bounds crash in that same splitting path
  under `--strip-underscore`, which shows the path is live and maintained.
- **Not the same as #178767.** The prior step's forward note guessed that
  #178767 ("llvm-cxxfilt cannot undecorate a valid c++ symbol") might be this
  bug from another angle. **It is not**, and it was checked: that symbol fails
  on the **argv** path too, so it is a demangler limitation, not the stdin
  splitter. This bug is specifically that argv and stdin disagree.
- **A patch is small and obvious** (widen `IsLegalItaniumChar` to accept bytes
  `>= 0x80`), but the delimiter question — whether the splitter should be
  byte-oriented or should treat a UTF-8 continuation byte as part of the word —
  is upstream's to settle. Offer, do not attach.

---

## Title

`[llvm-cxxfilt] stdin path fails to demangle names containing extended identifiers; the same symbol works as an argv argument`

## Body (paste below this line)

`llvm-cxxfilt` demangles a symbol whose `<source-name>` contains a non-ASCII
extended identifier when the symbol is given as a command-line argument, and
fails to demangle the identical symbol when it arrives on stdin.

```console
$ cat ext-id.cpp
int ∂(int x) { return x; }

$ clang++ -std=c++23 -c ext-id.cpp -o ext-id.o
$ llvm-nm --defined-only ext-id.o
0000000000000000 T _Z3∂i

$ llvm-cxxfilt '_Z3∂i'          # argv: works
∂(int)

$ echo '_Z3∂i' | llvm-cxxfilt   # stdin: unchanged
_Z3∂i

$ llvm-nm --defined-only ext-id.o | llvm-cxxfilt   # the realistic pipeline
0000000000000000 T _Z3∂i
```

The ASCII control behaves as expected on both paths (`echo _Z1fi | llvm-cxxfilt`
→ `f(int)`).

### Cause

The two paths differ by one boolean. `llvm_cxxfilt_main` calls `demangleLine`
with `Split=true` for stdin and `Split=false` for each argv operand
(`llvm/tools/llvm-cxxfilt/llvm-cxxfilt.cpp`, as of `72417eb739e5`):

```cpp
    for (std::string Mangled; std::getline(std::cin, Mangled);)
      demangleLine(llvm::outs(), Mangled, true);
  ...
      demangleLine(llvm::outs(), Symbol, false);
```

With `Split=true` the line is first cut into words by `SplitStringDelims`, and
the predicate that decides what a word is made of admits ASCII only:

```cpp
// This returns true if 'C' is a character that can show up in an
// Itanium-mangled string.
static bool IsLegalItaniumChar(char C) {
  // Itanium CXX ABI [External Names]p5.1.1:
  // '$' and '.' in mangled names are reserved for private implementations.
  return isAlnum(C) || C == '.' || C == '$' || C == '_';
}
```

`char` is signed on the usual targets, so each of the three UTF-8 bytes of `∂`
(`E2 88 82`) fails `isAlnum` and is treated as a delimiter. `_Z3∂i` is
therefore split into the words `_Z3` and `i` with `∂` as the delimiter between
them, neither word demangles, and the line is reassembled unchanged.

The comment above the predicate cites the ABI on `$` and `.`. The ABI's
`<source-name> ::= <positive length number> <identifier>` counts **bytes**, and
`<identifier>` is "the unqualified name in the source, encoded in the source
character set" — an extended identifier's UTF-8 bytes are part of the mangled
name, so the predicate is under-inclusive rather than wrong about `$`/`.`.

### Why it matters

Piping a symbol table or a disassembly through `llvm-cxxfilt` is the reason
the stdin path splits at all (#39337, which added it). Any translation unit
using extended identifiers — which C++ has permitted since C++11 and which
P1949 tightened rather than removed — produces symbols this path silently
passes through undemangled, in exactly the pipeline the feature was added for.
The failure is silent: there is no diagnostic and no exit-code change,
so a tool consuming the output sees a mangled name and cannot tell whether
that is because the name was not a symbol or because the splitter ate it.

### Suggested fix

Accept bytes with the high bit set in `IsLegalItaniumChar`:

```cpp
  return isAlnum(C) || C == '.' || C == '$' || C == '_' ||
         static_cast<unsigned char>(C) >= 0x80;
```

That keeps every existing delimiter (all ASCII punctuation and whitespace
still split) and makes a multi-byte identifier one word. Happy to send this as
a patch with a test if the shape is right — the alternative reading, that the
splitter should be UTF-8-aware rather than byte-oriented, is a bigger change
and it is not obvious it buys anything here.
