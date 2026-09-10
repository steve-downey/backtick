#!/usr/bin/env bash
# escape-errors.sh — the escape's error paths, and the ones that must not hang.
#
# The coverage sweep (escape-positions.sh) asks only *accepts or rejects*.
# This asks the other question: when an escape is malformed, or is well-formed
# but names nothing, does the parser diagnose and stop?
#
# It exists because it found one.  Teaching Clang the escape in a qualified
# type-specifier made `` namespace N { int x; } N::`union` g; `` -- a
# well-formed escape naming something that is not a type -- loop forever in
# ParseDeclarationSpecifiers: the recovery path for an unresolved qualified
# name is implicit-int, which does not apply to an escape, so the loop
# re-entered its own case with the token stream unchanged.  Every one of these
# is run under `timeout`, and a timeout is a failure, not a slow test.
#
#   ops/probes/escape-errors.sh
#   CLANG=... CC1PLUS=... TIMEOUT=10 ops/probes/escape-errors.sh
#
# Run it under bash.  Exit status is 1 if any probe hung or crashed.

set -u
CLANG=${CLANG:-$HOME/src/llvm/build-backtick-trunk/bin/clang++}
CC1PLUS=${CC1PLUS:-$HOME/bld/gcc/gcc-backtick-build/gcc/cc1plus}
STD=${STD:-c++20}
TIMEOUT=${TIMEOUT:-10}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

declare -a NAME=() PROG=()
add() { NAME+=("$1"); PROG+=("$2"); }

# Malformed escapes, in each of the four position categories.
add bad-not-keyword-decl    'int `notakeyword` = 0;'
add bad-not-keyword-class   'struct `notakeyword` { };'
add bad-not-keyword-qual    'namespace N { struct S{}; } N::`notakeyword` g;'
add bad-unterminated-decl   'int `new = 0;'
add bad-unterminated-class  'struct `int { };'
add bad-unterminated-qual   'namespace N { struct S{}; } N::`union g;'
add bad-empty-decl          'int ` = 0;'
add bad-empty-qual          'namespace N { struct S{}; } N::` g;'
add bad-nested-escape       'int ``new`` = 0;'

# Well-formed escapes naming nothing, or naming the wrong kind of thing.
# These are the shapes that made a recovery loop possible.
add undeclared-qual-type    'namespace N { int x; } N::`union` g;'
add undeclared-qual-empty   'namespace N { } N::`union` g;'
add undeclared-leading-ns   '`namespace`::S g;'
add undeclared-qual-alias   'namespace N { int x; } using X = N::`union`;'
add undeclared-qual-block   'namespace N { int x; } int f() { N::`union` s; return 0; }'
add undeclared-qual-sizeof  'namespace N { int x; } int f() { return sizeof(N::`union`); }'
add undeclared-qual-param   'namespace N { int x; } void f(N::`union`);'
add undeclared-qual-base    'namespace N { int x; } struct D : N::`union` { };'
add undeclared-qual-tmplarg 'namespace N { int x; } template <class T> struct W { }; W<N::`union`> w;'
add undeclared-typename     'namespace N { struct S{}; } template <class T> struct W { typename T::`union` m; }; W<N::S> w;'
add type-used-as-value      'namespace N { struct `union` { }; } int f() { return N::`union`; }'
add value-used-as-type      'namespace N { int `new`; } N::`new` g;'
add undeclared-ctor         'struct `union` { }; `union`::`nonexistent`() { }'
add double-escape-undecl    'namespace `namespace` { } `namespace`::`union` g;'

status=0
run() { # $1 label, $2 program, $3 compiler, $4 extra args...
    local label=$1 prog=$2 cc=$3; shift 3
    printf '%s\n' "$prog" > "$TMP/e.cpp"
    local out rc
    out=$(timeout "$TIMEOUT" "$cc" -std="$STD" -fbacktick -fsyntax-only "$@" \
              "$TMP/e.cpp" 2>&1); rc=$?
    case $rc in
      0)   printf '  %-24s ACCEPTED (expected a diagnostic)\n' "$label"; status=1 ;;
      124) printf '  %-24s ** HUNG ** after %ss\n' "$label" "$TIMEOUT"; status=1 ;;
      1)   printf '  %-24s diagnosed: %s\n' "$label" \
               "$(printf '%s' "$out" | grep -m1 -o 'error:.*' | cut -c1-64)" ;;
      *)   printf '  %-24s ** exit %s ** %s\n' "$label" "$rc" \
               "$(printf '%s' "$out" | head -1 | cut -c1-64)"; status=1 ;;
    esac
}

echo "clang   : $CLANG"
for ((i = 0; i < ${#NAME[@]}; i++)); do run "${NAME[$i]}" "${PROG[$i]}" "$CLANG"; done
echo "cc1plus : $CC1PLUS"
for ((i = 0; i < ${#NAME[@]}; i++)); do run "${NAME[$i]}" "${PROG[$i]}" "$CC1PLUS" -quiet; done
exit $status
