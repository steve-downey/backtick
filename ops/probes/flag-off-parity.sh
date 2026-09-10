#!/usr/bin/env bash
# flag-off-parity.sh — does the flag change a program that contains no
# backtick?
#
# The standing risk of the keyword-escape is not that it accepts too much; it
# is that a *lookahead* or a *lookup* moved for the escape's sake changes how a
# backtick-free program parses.  It has leaked three times, twice through
# diagnostics.  So the check is byte-identity, not "looks the same":
#
#   flag on  vs  flag off   on the same binary   — must be identical
#   flag off vs  a pristine upstream binary      — a weaker control: the two
#                binaries need not share an upstream revision, so a difference
#                here is a version difference until shown otherwise
#
# over -fsyntax-only, -ast-print and -ast-dump for Clang and -fsyntax-only plus
# generated assembly for GCC, on a well-formed and an ill-formed program that
# between them exercise every construct the escape's name positions touch.
#
#   CLANG=... PRISTINE_CLANG=... CC1PLUS=... PRISTINE_CC1PLUS=... \
#     ops/probes/flag-off-parity.sh
#
# -ast-dump is compared with 0x[0-9a-f]+ normalized: those are allocation
# addresses and differ run to run.  Run it under bash.

set -u
CLANG=${CLANG:-$HOME/src/llvm/build-backtick-trunk/bin/clang++}
PRISTINE_CLANG=${PRISTINE_CLANG:-$HOME/src/llvm/build-main/bin/clang++}
CC1PLUS=${CC1PLUS:-$HOME/bld/gcc/gcc-backtick-build/gcc/cc1plus}
PRISTINE_CC1PLUS=${PRISTINE_CC1PLUS:-$HOME/bld/gcc/build-trunk/gcc/cc1plus}
STD=${STD:-c++20}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/ok.cpp" <<'EOF'
// Well-formed, no backtick anywhere.  Every construct whose lookahead or
// lookup the keyword-escape work moved, including the builtin type names,
// which GCC binds at global scope and the escape now steps around.
namespace N { struct S { int a; struct Inner { int b; }; static int sf(); };
              int obj = 1; int fn(); namespace deep { struct T { int c; }; } }
namespace A = N;
using namespace N;
using X = N::S;
template <class T> using Y = T;
template <class T> concept C = true;
struct Base { Base(); Base(int); void m(); };
struct Der : Base { Der() : Base() { } Base b; };
enum E { EA };
enum class SE { SA };
template <class T> struct W { typename T::Inner m; };
template <template <class> class TT> struct V { TT<int> m; };
template <C T> void constrained();
N::S g;
N::S *gp;
struct N::S gg;
N::S::Inner gi;
A::S ga;
Y<N::S> gy;
typedef int myint;
int i0; long l0; char c0; bool b0; double d0; wchar_t w0;
unsigned u0; signed s0; short sh0; float f0;
myint m0;
int use() {
  N::S s; s.a = N::obj + N::fn() + N::S::sf();
  N::deep::T t; t.c = 0;
  Der d; d.m();
  return sizeof(N::S) + static_cast<N::S>(s).a + t.c + (int)EA + (int)SE::SA
         + i0 + (int)l0 + c0 + b0 + (int)d0 + (int)w0 + (int)u0 + s0 + sh0
         + (int)f0 + m0;
}
void Base::m() { }
Base::Base() { }
struct Q { void f(); }; void Q::f() { }
void labels() { top: ; goto top; }
EOF

cat > "$TMP/bad.cpp" <<'EOF'
// Ill-formed, no backtick anywhere.  The diagnostics are the payload.
namespace N { struct S { int a; }; }
N::T g1;
N::S::Missing g2;
using X = N::Nope;
struct D : N::Absent { };
int f1() { N::Gone s; return sizeof(N::AlsoGone); }
template <class T> struct W { typename T::none m; };
struct B { B(); }; struct C2 : B { C2() : Nothing() { } };
enum class SE { SA }; int f2() { return (int)SE::SB; }
namespace A = NotAName;
using namespace AlsoNot;
template <class T> concept C3 = true;
template <C4 T> void g3();
void lbl() { goto nowhere; }
int f4() { return N::S::nope; }
struct int2;
int int;
struct long { };
EOF

status=0
report() { # $1 label, $2 on-file, $3 off-file, $4 pristine-file(or "")
  local label=$1 n
  sed -E -i 's/0x[0-9a-f]+/0xADDR/g' "$2" "$3"; [ -n "$4" ] && sed -E -i 's/0x[0-9a-f]+/0xADDR/g' "$4"
  n=$(wc -l < "$2")
  if cmp -s "$2" "$3"; then
    printf '  %-32s flag on vs flag off   IDENTICAL (%s lines)\n' "$label" "$n"
  else
    printf '  %-32s flag on vs flag off   ** DIFFERS **\n' "$label"; diff "$2" "$3" | head -20; status=1
  fi
  if [ -n "$4" ]; then
    if cmp -s "$3" "$4"; then
      printf '  %-32s flag off vs pristine   IDENTICAL\n' ""
    else
      printf '  %-32s flag off vs pristine   differs in %s lines (version drift until shown otherwise)\n' \
             "" "$(diff "$3" "$4" | grep -c '^[<>]')"
    fi
  fi
}

echo "clang    : $CLANG"
echo "pristine : $PRISTINE_CLANG"
for spec in "ok.cpp|-fsyntax-only|-fsyntax-only, well-formed" \
            "bad.cpp|-fsyntax-only|-fsyntax-only, ill-formed" \
            "ok.cpp|-fsyntax-only -Xclang -ast-print|-ast-print" \
            "ok.cpp|-fsyntax-only -Xclang -ast-dump|-ast-dump"; do
  IFS='|' read -r file args label <<< "$spec"
  # shellcheck disable=SC2086
  "$CLANG" -std="$STD" -fbacktick $args "$TMP/$file" > "$TMP/on" 2>&1
  # shellcheck disable=SC2086
  "$CLANG" -std="$STD"            $args "$TMP/$file" > "$TMP/off" 2>&1
  pri=""
  if [ -x "$PRISTINE_CLANG" ]; then
    # shellcheck disable=SC2086
    "$PRISTINE_CLANG" -std="$STD" $args "$TMP/$file" > "$TMP/pri" 2>&1; pri="$TMP/pri"
  fi
  report "$label" "$TMP/on" "$TMP/off" "$pri"
done

echo "cc1plus  : $CC1PLUS"
echo "pristine : $PRISTINE_CC1PLUS"
for spec in "ok.cpp|-fsyntax-only|-fsyntax-only, well-formed" \
            "bad.cpp|-fsyntax-only|-fsyntax-only, ill-formed" \
            "ok.cpp|-o /dev/stdout|generated assembly"; do
  IFS='|' read -r file args label <<< "$spec"
  # shellcheck disable=SC2086
  "$CC1PLUS" -std="$STD" -quiet -fbacktick $args "$TMP/$file" > "$TMP/on" 2>&1
  # shellcheck disable=SC2086
  "$CC1PLUS" -std="$STD" -quiet            $args "$TMP/$file" > "$TMP/off" 2>&1
  pri=""
  if [ -x "$PRISTINE_CC1PLUS" ]; then
    # shellcheck disable=SC2086
    "$PRISTINE_CC1PLUS" -std="$STD" -quiet $args "$TMP/$file" > "$TMP/pri" 2>&1; pri="$TMP/pri"
  fi
  report "$label" "$TMP/on" "$TMP/off" "$pri"
done
exit $status
