#!/usr/bin/env bash
# escape-positions.sh — where does the keyword escape reach?
#
# One line per position: a complete C++ program that uses a backtick escape in
# exactly one grammatical position, and nothing else interesting.  Categories
# A–D escape a keyword; category E escapes a word that is not one, which is
# what escape-content decided and what those four never varied.  Each is compiled with `-fbacktick -fsyntax-only`; the only
# question asked is *accepts* or *rejects*.
#
# Run it under bash.  zsh does not word-split, which has cost this track
# several sweeps; the arrays below are bash arrays and the `for` loops
# depend on that.
#
#   probes/escape-positions.sh                     # both compilers
#   CLANG=... CC1PLUS=... probes/escape-positions.sh
#   probes/escape-positions.sh --verbose           # print each diagnostic
#
# Environment:
#   CLANG    a clang++ driver (default ~/src/llvm/build-backtick-trunk/bin/clang++)
#   CC1PLUS  a GCC cc1plus   (default ~/bld/gcc/gcc-backtick-build/gcc/cc1plus)
#            xg++ does not work in the GCC dev build; cc1plus is the entry point.
#   STD      language standard, default c++20 (concepts, alias templates,
#            scoped enums; the escape itself needs nothing newer than C++98)
#
# Exit status is 0 if every probe was run, whatever the verdicts; the table is
# the output.  A probe that *should* fail is not marked here — this sweep is a
# coverage map, not a test suite.  The test suites that pin the answers are
# clang/test/Parser/backtick-escape-positions.cpp and
# gcc/testsuite/g++.dg/backtick/escape-positions.C.

set -u

CLANG=${CLANG:-$HOME/src/llvm/build-backtick-trunk/bin/clang++}
CC1PLUS=${CC1PLUS:-$HOME/bld/gcc/gcc-backtick-build/gcc/cc1plus}
STD=${STD:-c++20}
VERBOSE=0
[ "${1:-}" = "--verbose" ] && VERBOSE=1

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# A. Declaration positions — where a name is *introduced*.
#    Seventeen grammatical rows; some rows are more than one spelling.
# ---------------------------------------------------------------------------
declare -a DECL_NAME=() DECL_PROG=()
add_decl() { DECL_NAME+=("$1"); DECL_PROG+=("$2"); }

add_decl decl-variable        'int `new` = 0;'
add_decl decl-function        'void `new`();'
add_decl decl-member          'struct S { int `new`; };'
add_decl decl-typedef         'typedef int `new`;'
add_decl decl-parameter       'void f(int `new`);'
add_decl decl-out-of-class    'struct S { void `new`(); }; void S::`new`() { }'
add_decl decl-friend          'struct S { friend void `new`(); };'
add_decl decl-nttp            'template <int `new`> struct S { };'
add_decl decl-using           'struct B { void `new`(); }; struct D : B { using B::`new`; };'
add_decl decl-primary-expr    'void `new`(); void f() { `new`(); }'
add_decl decl-member-access   'struct S { int `new`; }; int f(S s) { return s.`new`; }'
add_decl decl-alias           'using `class` = int;'
add_decl decl-alias-template  'template <class T> using `class` = T;'
add_decl decl-concept         'template <class T> concept `class` = true;'
add_decl decl-class-head      'struct `union` { };'
add_decl decl-enum-unscoped   'enum `enum` { A };'
add_decl decl-enum-scoped     'enum class `enum` { A };'
add_decl decl-enumerator      'enum E { `new` };'
add_decl decl-namespace       'namespace `namespace` { }'
add_decl decl-type-param      'template <class `typename`> struct S { };'
add_decl decl-template-param  'template <template <class> class `typename`> struct S { };'
add_decl decl-mem-initializer 'struct S { int `new`; S() : `new`(0) { } };'
add_decl decl-label           'void f() { `try`: ; goto `try`; }'

# ---------------------------------------------------------------------------
# B. Use positions — where the name introduced above is *named again*.
#    Declaring a name is half a hatch.
# ---------------------------------------------------------------------------
declare -a USE_NAME=() USE_PROG=()
add_use() { USE_NAME+=("$1"); USE_PROG+=("$2"); }

add_use use-type-specifier    'struct `union` { }; `union` u;'
add_use use-member-type       'struct `union` { }; struct S { `union` m; };'
add_use use-enum-type         'enum `enum` { A }; `enum` e = A;'
add_use use-enumerator        'enum E { `new` }; int f() { return `new`; }'
add_use use-scoped-enumerator 'enum class `enum` { A }; auto f() { return `enum`::A; }'
add_use use-namespace-member  'namespace `namespace` { int x; } int f() { return `namespace`::x; }'
add_use use-using-directive   'namespace `namespace` { } using namespace `namespace`;'
add_use use-alias             'using `class` = int; `class` x = 0;'
add_use use-alias-template    'template <class T> using `class` = T; `class`<int> x = 0;'
add_use use-type-constraint   'template <class T> concept `class` = true; template <`class` T> void f();'
add_use use-type-param        'template <class `typename`> struct S { `typename` m; };'
add_use use-template-param    'template <template <class> class `typename`> struct S { `typename`<int> m; };'
add_use use-base-specifier    'struct `union` { }; struct D : `union` { };'
add_use use-meminit-base      'struct `union` { }; struct D : `union` { D() : `union`() { } };'
add_use use-constructor       'struct `union` { `union`(); }; `union`::`union`() { }'
add_use use-nns-middle        'namespace `namespace` { namespace inner { int x; } } int f() { return `namespace`::inner::x; }'

# ---------------------------------------------------------------------------
# C. Qualified positions — an escape inside a *nested-name-specifier*, or the
#    final component of a qualified name that is read as a type rather than as
#    an unqualified-id.  This is the third category, swept first on 2026-09-08.
# ---------------------------------------------------------------------------
declare -a QUAL_NAME=() QUAL_PROG=()
add_qual() { QUAL_NAME+=("$1"); QUAL_PROG+=("$2"); }

# The qualifier is escaped, the final component is not.
add_qual qual-class-scope-ns    'struct `union` { struct S { int a; }; }; `union`::S g;'
add_qual qual-class-scope-block 'struct `union` { struct S { int a; }; }; int f() { `union`::S s; return s.a; }'
add_qual qual-ns-scope-ns       'namespace `namespace` { struct S { int a; }; } `namespace`::S g;'
add_qual qual-ns-scope-block    'namespace `namespace` { struct S { int a; }; } int f() { `namespace`::S s{1}; return s.a; }'
add_qual qual-ns-object-block   'namespace `namespace` { int x; } int f() { return `namespace`::x; }'
add_qual qual-class-static-fn   'struct `union` { static int f(); }; int g() { return `union`::f(); }'

# The final component is escaped and is a *type*.
add_qual qual-final-type-decl   'namespace N { struct `union` { int a; }; } N::`union` g;'
add_qual qual-final-type-alias  'namespace N { struct `union` { int a; }; } using X = N::`union`;'
add_qual qual-final-type-sizeof 'namespace N { struct `union` { int a; }; } int f() { return sizeof(N::`union`); }'
add_qual qual-final-type-block  'namespace N { struct `union` { int a; }; } int f() { N::`union` s; return s.a; }'
add_qual qual-final-type-param  'namespace N { struct `union` { int a; }; } void f(N::`union`);'
add_qual qual-final-type-return 'namespace N { struct `union` { int a; }; } N::`union` f();'
add_qual qual-final-type-new    'namespace N { struct `union` { int a; }; } void *f() { return new N::`union`; }'
add_qual qual-final-type-tmplarg 'namespace N { struct `union` { int a; }; } template <class T> struct W { }; W<N::`union`> w;'
add_qual qual-final-type-elab   'namespace N { struct `union` { int a; }; } struct N::`union` g;'
add_qual qual-final-type-base   'namespace N { struct `union` { int a; }; } struct D : N::`union` { };'
add_qual qual-final-type-meminit 'namespace N { struct `union` { int a; }; } struct D : N::`union` { D() : N::`union`() { } };'
add_qual qual-final-type-cast   'namespace N { struct `union` { int a; }; } int f(N::`union` u) { return static_cast<N::`union`>(u).a; }'
add_qual qual-final-type-nested 'namespace N { struct `union` { struct S { int a; }; }; } N::`union`::S g;'
add_qual qual-final-type-dependent 'namespace N { struct `union` { }; } template <class T> struct W { typename T::`union` m; };'

# The final component is escaped and is an *object* or a *function*.
add_qual qual-final-object      'namespace N { int `new` = 1; } int f() { return N::`new`; }'
add_qual qual-final-function    'namespace N { int `new`(); } int f() { return N::`new`(); }'

# Both halves escaped.
add_qual qual-both-escaped      'namespace `namespace` { struct `union` { int a; }; } `namespace`::`union` g;'

# Out-of-class definition whose *class* is escaped.
add_qual qual-out-of-class-cls  'struct `union` { void f(); }; void `union`::f() { }'
add_qual qual-out-of-class-both 'struct `union` { void `new`(); }; void `union`::`new`() { }'

# ---------------------------------------------------------------------------
# D. Type-keyword escapes — an escape whose keyword is a *type* keyword.
#    GCC binds `int' and its siblings at global scope so that code which looks
#    builtin types up by name can find them; Clang's keywords carry no
#    binding.  Every probe anyone wrote before 2026-09-08 used `new', `class',
#    `union' or `try', which are pure keywords, and the divergence hid behind
#    that choice for two months.
# ---------------------------------------------------------------------------
declare -a TYPE_NAME=() TYPE_PROG=()
add_type() { TYPE_NAME+=("$1"); TYPE_PROG+=("$2"); }

add_type type-variable       'int `int` = 0;'
add_type type-function       'void `long`();'
add_type type-alias          'using `int` = char;'
add_type type-class-head     'struct `int` { };'
add_type type-alias-template 'template <class T> using `long` = T;'
add_type type-enum           'enum `int` { A };'
add_type type-namespace      'namespace `int` { }'
add_type type-parameter      'void f(int `int`);'
add_type type-member         'struct S { int `int`; };'
add_type type-local          'void f() { int `int` = 0; (void)`int`; }'
add_type type-use-variable   'int `int` = 0; int f() { return `int`; }'
add_type type-use-class      'struct `int` { int a; }; `int` v; int f() { return v.a; }'
add_type type-use-alias      'using `int` = char; `int` c = 0;'
add_type type-use-namespace  'namespace `int` { int x; } int f() { return `int`::x; }'
add_type type-coexists       'struct `int` { int a; }; int x = 0; `int` v{1}; int f() { return v.a + x + sizeof(int); }'

# ---------------------------------------------------------------------------
# E. The word is not a keyword — escape-content, decided 2026-09-17.
#    Categories A–D vary the *position* four ways and never once varied the
#    word: every one of their seventy-nine programs escapes a keyword, because
#    until 2026-09-17 the rule required one.  These are A's and D's shapes with
#    an ordinary identifier in the backticks, plus the two consequences that
#    only show up here: that the escaped and unescaped spellings are one name,
#    and that an alternative token ([lex.digraph]) is a word like any other.
#
#    Run the whole sweep twice, STD=c++17 and STD=c++20.  This category is the
#    one whose verdicts must be *identical* in the two runs — that is the point
#    of the decision, and `requires' is the program that shows it.
# ---------------------------------------------------------------------------
declare -a WORD_NAME=() WORD_PROG=()
add_word() { WORD_NAME+=("$1"); WORD_PROG+=("$2"); }

add_word word-variable        'int `foobar` = 0;'
add_word word-function        'void `foobar`();'
add_word word-alias           'using `foobar` = char;'
add_word word-class-head      'struct `foobar` { };'
add_word word-alias-template  'template <class T> using `foobar` = T;'
add_word word-enum            'enum `foobar` { A };'
add_word word-namespace       'namespace `foobar` { }'
add_word word-parameter       'void f(int `foobar`);'
add_word word-member          'struct S { int `foobar`; };'
add_word word-local           'void f() { int `foobar` = 0; (void)`foobar`; }'
add_word word-identity        'int `foobar` = 0; int f() { return foobar; }'
add_word word-identity-rev    'int foobar = 0; int f() { return `foobar`; }'
add_word word-use-class       'struct `foobar` { int a; }; `foobar` v; int f() { return v.a; }'
add_word word-qualified       'namespace `ns` { int `x`; } int f() { return ns::x + `ns`::`x`; }'
add_word word-template-param  'template <class `T`> struct S { `T` v; }; S<int> s;'
add_word word-label           'void f() { goto `done`; `done`: ; }'
add_word word-altern-token    'int `and` = 0; int f() { return `and`; }'
add_word word-altern-type     'struct `or` { int a; }; `or` v; int f() { return v.a; }'
add_word word-future-keyword  'bool `requires`(int); bool f(int x) { return `requires`(x); }'

# ---------------------------------------------------------------------------
run_one() {  # $1 program, $2 outfile-prefix; sets CLANG_R and GCC_R
    local prog=$1 pfx=$2
    printf '%s\n' "$prog" > "$TMP/$pfx.cpp"
    if [ -x "$CLANG" ]; then
        if "$CLANG" -std="$STD" -fbacktick -fsyntax-only "$TMP/$pfx.cpp" \
                > "$TMP/$pfx.clang" 2>&1; then CLANG_R=accepts; else CLANG_R=REJECTS; fi
    else CLANG_R=-; fi
    if [ -x "$CC1PLUS" ]; then
        if "$CC1PLUS" -std="$STD" -fbacktick -fsyntax-only -quiet "$TMP/$pfx.cpp" \
                > "$TMP/$pfx.gcc" 2>&1; then GCC_R=accepts; else GCC_R=REJECTS; fi
    else GCC_R=-; fi
}

sweep() {  # $1 heading, then name/prog array names
    local heading=$1 nvar=$2 pvar=$3
    local -n names=$nvar
    local -n progs=$pvar
    local i cok=0 gok=0 n=${#names[@]}
    echo
    echo "== $heading ($n programs) =="
    printf '%-26s %-8s %-8s\n' "position" "clang" "gcc"
    for ((i = 0; i < n; i++)); do
        run_one "${progs[$i]}" "p$$_${nvar}_$i"
        printf '%-26s %-8s %-8s\n' "${names[$i]}" "$CLANG_R" "$GCC_R"
        [ "$CLANG_R" = accepts ] && cok=$((cok + 1))
        [ "$GCC_R" = accepts ] && gok=$((gok + 1))
        if [ "$VERBOSE" = 1 ]; then
            [ "$CLANG_R" = REJECTS ] && sed 's/^/    clang: /' "$TMP/p$$_${nvar}_$i.clang"
            [ "$GCC_R" = REJECTS ] && sed 's/^/    gcc:   /' "$TMP/p$$_${nvar}_$i.gcc"
        fi
    done
    printf '%-26s %-8s %-8s\n' "TOTAL" "$cok/$n" "$gok/$n"
    TOT_C=$((TOT_C + cok)); TOT_G=$((TOT_G + gok)); TOT_N=$((TOT_N + n))
}

echo "clang   : $CLANG"
echo "cc1plus : $CC1PLUS"
echo "std     : $STD"
TOT_C=0; TOT_G=0; TOT_N=0
sweep "A. Declaration positions" DECL_NAME DECL_PROG
sweep "B. Use positions"         USE_NAME  USE_PROG
sweep "C. Qualified positions"   QUAL_NAME QUAL_PROG
sweep "D. Type-keyword escapes"  TYPE_NAME TYPE_PROG
sweep "E. Non-keyword words"     WORD_NAME WORD_PROG
echo
printf '%-26s %-8s %-8s\n' "ALL" "$TOT_C/$TOT_N" "$TOT_G/$TOT_N"
