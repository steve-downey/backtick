#!/usr/bin/env bash
# slot-callee.sh — is the slot the callee, whatever kind of expression it is?
#
# D4307R2's [expr.backtick] p1, rebased onto P4176R2, says E1 `O` E2 is the
# function-call-expression O(E1, E2) if O is a postfix-expression, and
# (O)(E1, E2) otherwise: the slot is evaluated and the result applied to the
# operands.  That was always the intent; R1's O(E1, E2) left it implicit, and
# pasted as tokens x `*p` y would read *p(x, y), i.e. *(p(x, y)).  See
# desugaring-target in docs/backtick-operator-design.md.
#
# Each row is a pair of programs: one written with the operator, and the same
# program with the operator spelled out as p1 now reads.  Both are compiled
# -fsyntax-only, with -fbacktick on the first only.  The answers are pinned by
# static_assert, so "accepts" means the value came out right and not merely
# that it parsed.  The questions asked of each row:
#
#   expect   what the row should do: most should be accepted; the ADL-off
#            rows should be rejected, because a written-parenthesized slot
#            suppresses ADL exactly as (f)(x, y) does
#   clang / gcc         the operator form, on each prototype
#   =call               whether that verdict equals the spelled form's on the
#                       same binary (the thesis: it is sugar for the call)
#
# Rows marked "postfix" are controls: O is a postfix-expression, so p1's two
# readings coincide even if O(E1, E2) is pasted as tokens.
#
# Run it under bash; the arrays are bash arrays.
#
#   probes/slot-callee.sh
#   CLANG=... CC1PLUS=... probes/slot-callee.sh --verbose
#   SPELLED_ONLY=1 CLANG=clang++ CC1PLUS=$(g++ -print-prog-name=cc1plus) \
#     probes/slot-callee.sh      # check the spelled half on stock compilers
#
# Environment:
#   CLANG    a clang++ driver (default ~/src/llvm/build-backtick-trunk/bin/clang++)
#   CC1PLUS  a GCC cc1plus   (default ~/bld/gcc/gcc-backtick-build/gcc/cc1plus)
#   STD      language standard, default c++23
#   SPELLED_ONLY  1 compiles only the spelled half, without -fbacktick
#
# Exit status is 1 if any verdict differs from expect, or any operator form
# differs from its spelled form; 0 otherwise.

set -u

CLANG=${CLANG:-$HOME/src/llvm/build-backtick-trunk/bin/clang++}
CC1PLUS=${CC1PLUS:-$HOME/bld/gcc/gcc-backtick-build/gcc/cc1plus}
STD=${STD:-c++23}
SPELLED_ONLY=${SPELLED_ONLY:-0}
VERBOSE=0
[ "${1:-}" = "--verbose" ] && VERBOSE=1
command -v "$CLANG" > /dev/null 2>&1 && CLANG=$(command -v "$CLANG")
command -v "$CC1PLUS" > /dev/null 2>&1 && CC1PLUS=$(command -v "$CC1PLUS")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Shared by every row.  add and sub tell apart which callee was reached.
PRELUDE='
constexpr int add(int a, int b) { return a + b; }
constexpr int sub(int a, int b) { return a - b; }
using fn = int (*)(int, int);
constexpr fn p = add;
constexpr fn fns[] = { add, sub };
struct H { fn f; static constexpr int g(int a, int b) { return a * b; } };
constexpr H h{ sub };
namespace N {
  struct S { };
  constexpr int f(S, S) { return 1; }
}
struct Pair { int a, b; constexpr Pair(int x, int y) : a(x), b(y) { } };
'

declare -a NAME=() KIND=() EXPECT=() OP=() CALL=()
add_row() { NAME+=("$1"); KIND+=("$2"); EXPECT+=("$3"); OP+=("$4"); CALL+=("$5"); }

# --- O is not a postfix-expression: p1's second reading, (O)(E1, E2) -------
add_row deref-pointer        unary    accepts \
  'static_assert((2 `*p` 3) == 5);' \
  'static_assert(((*p)(2, 3)) == 5);'
add_row deref-arith          unary    accepts \
  'static_assert((7 `*(fns + 1)` 3) == 4);' \
  'static_assert(((*(fns + 1))(7, 3)) == 4);'
add_row address-of           unary    accepts \
  'static_assert((2 `&add` 3) == 5);' \
  'static_assert(((&add)(2, 3)) == 5);'
add_row conditional          cond     accepts \
  'static_assert((7 `false ? add : sub` 3) == 4);' \
  'static_assert(((false ? add : sub)(7, 3)) == 4);'
add_row assignment           assign   accepts \
  'constexpr int t() { fn q = nullptr; return 7 `q = sub` 3; } static_assert(t() == 4);' \
  'constexpr int t() { fn q = nullptr; return (q = sub)(7, 3); } static_assert(t() == 4);'
add_row cast                 cast     accepts \
  'static_assert((7 `(fn)sub` 3) == 4);' \
  'static_assert((((fn)sub)(7, 3)) == 4);'
add_row deref-in-template    unary    accepts \
  'template <class T> constexpr T t(T x, T y) { return x `*p` y; } static_assert(t(2, 3) == 5);' \
  'template <class T> constexpr T t(T x, T y) { return (*p)(x, y); } static_assert(t(2, 3) == 5);'
add_row deref-dependent      unary    accepts \
  'template <auto P> constexpr int t() { return 7 `*P` 3; } static_assert(t<sub>() == 4);' \
  'template <auto P> constexpr int t() { return (*P)(7, 3); } static_assert(t<sub>() == 4);'

# --- O is a postfix-expression: both readings agree (controls) -------------
add_row unqualified-id       postfix  accepts \
  'static_assert((7 `sub` 3) == 4);' \
  'static_assert((sub(7, 3)) == 4);'
add_row subscript            postfix  accepts \
  'static_assert((7 `fns[1]` 3) == 4);' \
  'static_assert((fns[1](7, 3)) == 4);'
add_row member-access        postfix  accepts \
  'static_assert((7 `h.f` 3) == 4);' \
  'static_assert((h.f(7, 3)) == 4);'
add_row qualified-id         postfix  accepts \
  'static_assert((2 `H::g` 3) == 6);' \
  'static_assert((H::g(2, 3)) == 6);'
add_row lambda               postfix  accepts \
  'static_assert((2 `[](int a, int b) { return a * b; }` 3) == 6);' \
  'static_assert(([](int a, int b) { return a * b; }(2, 3)) == 6);'
add_row type-slot            type     accepts \
  'static_assert((2 `Pair` 3).b == 3);' \
  'static_assert((Pair(2, 3)).b == 3);'

# --- ADL: kept for a bare name, lost to written parentheses -----------------
add_row adl-bare-name        postfix  accepts \
  'static_assert((N::S{} `f` N::S{}) == 1);' \
  'static_assert((f(N::S{}, N::S{})) == 1);'
add_row adl-bare-in-template postfix  accepts \
  'template <class T> constexpr int t(T x) { return x `f` x; } static_assert(t(N::S{}) == 1);' \
  'template <class T> constexpr int t(T x) { return f(x, x); } static_assert(t(N::S{}) == 1);'
add_row adl-off-parenthesized paren   REJECTS \
  'static_assert((N::S{} `(f)` N::S{}) == 1);' \
  'static_assert(((f)(N::S{}, N::S{})) == 1);'
add_row adl-off-in-template  paren    REJECTS \
  'template <class T> constexpr int t(T x) { return x `(f)` x; } static_assert(t(N::S{}) == 1);' \
  'template <class T> constexpr int t(T x) { return (f)(x, x); } static_assert(t(N::S{}) == 1);'

# ---------------------------------------------------------------------------
compile() {  # $1 compiler kind, $2 file, $3 flag ("" or -fbacktick); echo verdict
    local kind=$1 file=$2 flag=$3
    if [ "$kind" = clang ]; then
        [ -x "$CLANG" ] || { echo -; return; }
        "$CLANG" -std="$STD" $flag -fsyntax-only "$file" > "$file.clang" 2>&1
    else
        [ -x "$CC1PLUS" ] || { echo -; return; }
        "$CC1PLUS" -std="$STD" $flag -fsyntax-only -quiet "$file" > "$file.gcc" 2>&1
    fi && echo accepts || echo REJECTS
}

echo "clang   : $CLANG"
echo "cc1plus : $CC1PLUS"
echo "std     : $STD"
[ "$SPELLED_ONLY" = 1 ] && echo "mode    : spelled half only, no -fbacktick"
echo
printf '%-22s %-8s %-8s %-8s %-6s %-8s %-6s\n' row kind expect clang =call gcc =call
fail=0
for ((i = 0; i < ${#NAME[@]}; i++)); do
    printf '%s\n%s\n' "$PRELUDE" "${OP[$i]}"   > "$TMP/op$i.cpp"
    printf '%s\n%s\n' "$PRELUDE" "${CALL[$i]}" > "$TMP/call$i.cpp"
    line=$(printf '%-22s %-8s %-8s' "${NAME[$i]}" "${KIND[$i]}" "${EXPECT[$i]}")
    for kind in clang gcc; do
        call=$(compile $kind "$TMP/call$i.cpp" "")
        if [ "$SPELLED_ONLY" = 1 ]; then
            got=$call; same=
        else
            got=$(compile $kind "$TMP/op$i.cpp" -fbacktick)
            if [ "$got" = - ] || [ "$call" = - ]; then same=
            elif [ "$got" = "$call" ]; then same=yes
            else same=NO; fail=1; fi
        fi
        [ "$got" != - ] && [ "$got" != "${EXPECT[$i]}" ] && { got="$got!"; fail=1; }
        line+=$(printf ' %-8s %-6s' "$got" "$same")
        if [ "$VERBOSE" = 1 ]; then
            f="$TMP/op$i.cpp"; [ "$SPELLED_ONLY" = 1 ] && f="$TMP/call$i.cpp"
            [ -s "$f.$kind" ] && extra+=$(sed "s|^|    $kind: |" "$f.$kind")$'\n'
        fi
    done
    echo "$line"
    [ "$VERBOSE" = 1 ] && [ -n "${extra:-}" ] && printf '%s' "$extra"
    extra=
done
echo
[ "$fail" = 0 ] && echo "all rows as expected" || echo "MISMATCH (marked ! or NO)"
exit $fail
