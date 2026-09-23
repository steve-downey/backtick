#!/usr/bin/env bash
# scripts/compare.sh
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# What the two spellings cost.
#
# Every example ships twice from sources that differ only in how they spell
# their calls, and <name>.equivalent already proves the two programs print the
# same thing. That says nothing about what the compiler did to get there. This
# script measures it, along three axes:
#
#   codegen    are the objects the same? bit-identical, or identical modulo
#              symbol sizes and assembly, or -- where they differ -- what by?
#   compile    what did the front end and back end spend to produce them?
#   consteval  how many constant-evaluation steps does each spelling cost,
#              and do the two grow at the same rate?
#
# The consteval axis is the only exact one: -fconstexpr-steps is bisected to
# the least value that compiles, which is a count, not a measurement. The
# compile axis is timing, so it reports a noise floor -- the same file
# measured twice under two labels -- and no delta below that floor means
# anything.
#
# Usage:
#   scripts/compare.sh [--toolchain NAME] [--examples a,b,c] [--opts "-O0 -O2"]
#                      [--reps N] [--sizes "100 200 400"] [--only AXIS] [--out DIR]
#
# Defaults to the clang-23 prototype, every discovered pair, -O0/-O2/-O3, and
# writes docs/comparison/<toolchain>.{md,csv}. A full run takes a while --
# calendar at -O0 is minutes on its own. --only writes
# <toolchain>.<axis>.{md,csv} instead, leaving the full report alone: the
# timings are worth retaking on a quiet machine, and the other two axes are
# deterministic and do not change until the compiler does.

# The report is markdown, and markdown is full of backticks. Single-quoted
# prose here is prose, not an unexpanded expression.
# shellcheck disable=SC2016

set -euo pipefail

# Sorting, comm, and diff all have to agree on collation, and the report is
# checked in from whatever machine runs it.
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT

TOOLCHAIN=clang-23-backticks
EXAMPLES=
OPTS="-O0 -O2 -O3"
REPS=3
SIZES="100 200 400 800"
ONLY=
OUT=

die() {
    echo "compare.sh: $*" >&2
    exit 1
}

usage() {
    sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's|^# \?||'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --toolchain) TOOLCHAIN="$2"; shift 2 ;;
        --examples) EXAMPLES="${2//,/ }"; shift 2 ;;
        --opts) OPTS="$2"; shift 2 ;;
        --reps) REPS="$2"; shift 2 ;;
        --sizes) SIZES="$2"; shift 2 ;;
        --only) ONLY="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        -h | --help) usage ;;
        *) die "unknown option $1 (try --help)" ;;
    esac
done

readonly BUILD="${ROOT}/.build/build-${TOOLCHAIN}"
readonly CCJSON="${BUILD}/compile_commands.json"
readonly OUTDIR="${OUT:-${ROOT}/docs/comparison}"
# A partial run gets its own pair of files. Truncating the full report to
# one section loses the other two, and the axes are refreshed at different
# rates: codegen and consteval are deterministic and only change when the
# compiler does, while the timings are worth retaking on a quiet machine.
case "${ONLY}" in
    '' | codegen | compile | consteval) ;;
    *) die "--only takes codegen, compile, or consteval" ;;
esac

readonly REPORT="${OUTDIR}/${TOOLCHAIN}${ONLY:+.${ONLY}}.md"
readonly CSV="${OUTDIR}/${TOOLCHAIN}${ONLY:+.${ONLY}}.csv"

[[ -f ${CCJSON} ]] ||
    die "no ${CCJSON}. Run: make cmake TOOLCHAIN=${TOOLCHAIN}"
command -v jq >/dev/null || die "jq is required"

CXX="$(jq -r '.[0].command' "${CCJSON}" | awk '{print $1}')"
[[ -x ${CXX} ]] || die "compiler ${CXX} from ${CCJSON} is not executable"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Pin to one core. Timing on a machine with 20 of them otherwise measures the
# scheduler as much as the compiler.
PIN=(taskset -c 2)
command -v taskset >/dev/null || PIN=()

# ---------------------------------------------------------------------------
# Discovery

# The pairs are whatever ships twice: <dir>/<name>.pipe.cpp beside
# <dir>/<name>.backtick.cpp. Nothing here needs a list to be maintained.
discover() {
    local f name
    for f in "${ROOT}"/src/examples/*/*.pipe.cpp; do
        name="$(basename "${f}" .pipe.cpp)"
        [[ -f ${f%.pipe.cpp}.backtick.cpp ]] || continue
        echo "${name} ${f%/*}"
    done
}

PAIRS=()
while read -r name dir; do
    [[ -z ${EXAMPLES} || " ${EXAMPLES} " == *" ${name} "* ]] || continue
    PAIRS+=("${name}:${dir}")
done < <(discover)
[[ ${#PAIRS[@]} -gt 0 ]] || die "no example pairs matched"

# The flags the build actually uses for this file, minus everything this
# script varies itself: the optimization level, the debug level, the backtick
# flag, the module map, and the output. Keeping the rest -- include paths,
# -std, -stdlib, warnings -- means the measurement is of the real build, not
# of a set of flags invented here.
flags_for() {
    jq -r --arg f "$1" '[.[] | select(.file == $f)][0].command // empty' "${CCJSON}" |
        tr ' ' '\n' |
        grep -v -e '^$' -e '^-DCMAKE_INTDIR' -e '^@' -e '^-o$' -e '^-c$' \
            -e '^-O' -e '^-g' -e '^-DNDEBUG$' -e '^-f\(no-\)\?backtick$' \
            -e '^-fsanitize' -e '\.o$' -e '\.cpp$' -e "^${CXX}$" |
        tr '\n' ' '
}

variant_flag() { [[ $1 == pipe ]] && echo -fno-backtick || echo -fbacktick; }

# Both variants are compiled from a file of the same name in different
# directories. The only byte that differed in an earlier probe was the source
# name the assembler puts in .strtab, and that is not a difference in code.
#
# Moving a source out of its directory only works because every include here
# is canonical and angle-bracketed. A quoted include would resolve against
# the copy's directory and not be found, which is the failure the rule
# against them predicts.
stage() {
    local dir="$1" name="$2" variant="$3"
    mkdir -p "${WORK}/${variant}"
    cp "${dir}/${name}.${variant}.cpp" "${WORK}/${variant}/tu.cpp"
}

# ---------------------------------------------------------------------------
# Reporting

# The CSV is tidy -- one row per measurement -- so it can be pivoted
# without knowing which axis wrote which column.
csv() {
    local axis="$1" example="$2" key="$3"
    shift 3
    while [[ $# -gt 0 ]]; do
        echo "${axis},${example},${key},$1,$2" >>"${CSV}"
        shift 2
    done
}
md() { echo "$*" >>"${REPORT}"; }

# ---------------------------------------------------------------------------
# Axis 1: codegen

# Comments are not code. Clang annotates basic-block labels with the LLVM
# value names they came from, and those carry inlining-order suffixes
# (.i.i51 against .i.i42) that differ between two compilations which emit
# byte-identical objects. String data is exempt from comment stripping, since
# a literal may contain a # of its own.
norm_asm() {
    sed -e 's/[[:space:]]*$//' \
        -e '/^[[:space:]]*\.file/d' \
        -e '/^[[:space:]]*\.ident/d' \
        -e '/^[[:space:]]*#/d' \
        -e '/\.\(asci[iz]\|string\)/!s/[[:space:]]*#.*$//' "$1"
}

symbols() { nm --defined-only "$1" | awk '{print $NF}' | sort; }

# Clang numbers the closure types in a translation unit in order, so a source
# that declares a different number of lambdas ahead of one gives it a
# different ordinal. That renames a symbol; it does not change any code. This
# renumbering makes the two sets comparable on everything except the numbers.
strip_ordinals() { sed 's/\$_[0-9][0-9]*/$_N/g'; }

sym_sizes() {
    nm -S --defined-only "$1" |
        awk 'NF == 4 {print $NF, strtonum("0x" $2)}' | sort
}

text_size() { size "$1" | awk 'NR == 2 {print $1}'; }

codegen() {
    md '## Codegen'
    md ''
    md 'Compiled at `-g0`, so debug info -- which embeds the source name and'
    md 'therefore always differs -- is out of the comparison. `-g` does not'
    md 'change the instructions clang selects.'
    md ''
    md '| example | opt | identical object | .text pipe | .text backtick | delta | symbols | symbol set | asm diff |'
    md '|---|---|---|---|---|---|---|---|---|'

    local pair name dir opt flags tp tb sp sb ident
    local symdiff symdiff_n asmdiff asmdiff_n symcell asmcell
    local -a differ=() renamed=()

    for pair in "${PAIRS[@]}"; do
        name="${pair%%:*}"
        dir="${pair#*:}"
        stage "${dir}" "${name}" pipe
        stage "${dir}" "${name}" backtick
        flags="$(flags_for "${dir}/${name}.pipe.cpp")"
        [[ -n ${flags} ]] || die "${name} is not in ${CCJSON}; build it first"

        for opt in ${OPTS}; do
            for variant in pipe backtick; do
                (
                    cd "${WORK}/${variant}"
                    # shellcheck disable=SC2086
                    "${CXX}" ${flags} "${opt}" -g0 -DNDEBUG \
                        "$(variant_flag "${variant}")" -c tu.cpp -o tu.o
                    # shellcheck disable=SC2086
                    "${CXX}" ${flags} "${opt}" -g0 -DNDEBUG \
                        "$(variant_flag "${variant}")" -S tu.cpp -o tu.s
                )
            done

            tp="$(text_size "${WORK}/pipe/tu.o")"
            tb="$(text_size "${WORK}/backtick/tu.o")"
            sp="$(symbols "${WORK}/pipe/tu.o" | wc -l)"
            sb="$(symbols "${WORK}/backtick/tu.o" | wc -l)"
            symdiff="$(diff <(symbols "${WORK}/pipe/tu.o") \
                <(symbols "${WORK}/backtick/tu.o") | grep -c '^[<>]' || true)"
            symdiff_n="$(diff <(symbols "${WORK}/pipe/tu.o" | strip_ordinals) \
                <(symbols "${WORK}/backtick/tu.o" | strip_ordinals) |
                grep -c '^[<>]' || true)"
            asmdiff="$(diff <(norm_asm "${WORK}/pipe/tu.s") \
                <(norm_asm "${WORK}/backtick/tu.s") | grep -c '^[<>]' || true)"
            asmdiff_n="$(diff <(norm_asm "${WORK}/pipe/tu.s" | strip_ordinals) \
                <(norm_asm "${WORK}/backtick/tu.s" | strip_ordinals) |
                grep -c '^[<>]' || true)"
            if cmp -s "${WORK}/pipe/tu.o" "${WORK}/backtick/tu.o"; then
                ident='**yes**'
            else
                ident='no'
            fi

            if [[ ${symdiff} -eq 0 ]]; then
                symcell=same
            elif [[ ${symdiff_n} -eq 0 ]]; then
                symcell='ordinals only'
            else
                symcell="${symdiff} lines"
            fi
            if [[ ${asmdiff} -eq 0 ]]; then
                asmcell=0
            elif [[ ${asmdiff_n} -eq 0 ]]; then
                asmcell="${asmdiff}, none renumbered"
            else
                asmcell="${asmdiff} lines"
            fi

            md "| \`${name}\` | ${opt} | ${ident} | ${tp} | ${tb} | $((tb - tp)) | ${sp} / ${sb} | ${symcell} | ${asmcell} |"
            csv codegen "${name}" "${opt}" \
                identical_object "$([[ ${ident} == 'no' ]] && echo 0 || echo 1)" \
                text_pipe "${tp}" text_backtick "${tb}" \
                symbols_pipe "${sp}" symbols_backtick "${sb}" \
                symbol_set_diff_lines "${symdiff}" \
                symbol_set_diff_lines_renumbered "${symdiff_n}" \
                asm_diff_lines "${asmdiff}" \
                asm_diff_lines_renumbered "${asmdiff_n}"

            [[ ${asmdiff_n} -eq 0 ]] || differ+=("${name} ${opt}")
            if [[ ${asmdiff} -ne 0 && ${asmdiff_n} -eq 0 ]]; then
                renamed+=("${name} at ${opt}")
            fi
        done
    done

    md ''
    if [[ ${#renamed[@]} -gt 0 ]]; then
        md 'Identical code under different names -- the assembly matches once'
        md 'anonymous-lambda ordinals are renumbered, so what differs is what'
        md 'two closure types are called, not what any of it does:'
        md ''
        local case
        for case in "${renamed[@]}"; do
            md "- \`${case%% *}\` ${case#* }"
        done
        md ''
    fi
    if [[ ${#differ[@]} -eq 0 ]]; then
        md 'No pair differed in any instruction at any level measured.'
        md ''
        return
    fi

    # Where they differ, say what by. A byte count is not a finding.
    md '### Where they differ'
    md ''
    local entry only_p only_b resized
    for entry in "${differ[@]}"; do
        read -r name opt <<<"${entry}"
        dir=
        for pair in "${PAIRS[@]}"; do
            [[ ${pair%%:*} == "${name}" ]] && dir="${pair#*:}"
        done
        stage "${dir}" "${name}" pipe
        stage "${dir}" "${name}" backtick
        flags="$(flags_for "${dir}/${name}.pipe.cpp")"
        for variant in pipe backtick; do
            (
                cd "${WORK}/${variant}"
                # shellcheck disable=SC2086
                "${CXX}" ${flags} "${opt}" -g0 -DNDEBUG \
                    "$(variant_flag "${variant}")" -c tu.cpp -o tu.o
            )
        done

        sym_sizes "${WORK}/pipe/tu.o" >"${WORK}/p.syms"
        sym_sizes "${WORK}/backtick/tu.o" >"${WORK}/b.syms"
        cut -d' ' -f1 "${WORK}/p.syms" >"${WORK}/p.names"
        cut -d' ' -f1 "${WORK}/b.syms" >"${WORK}/b.names"

        only_p="$(comm -23 "${WORK}/p.names" "${WORK}/b.names" | wc -l)"
        only_b="$(comm -13 "${WORK}/p.names" "${WORK}/b.names" | wc -l)"
        resized="$(join "${WORK}/p.syms" "${WORK}/b.syms" | awk '$2 != $3' | wc -l)"

        md "#### \`${name}\` at ${opt}"
        md ''
        md "Instantiated only by the pipe spelling: ${only_p}. Only by the"
        md "backtick spelling: ${only_b}. In both, at a different size:"
        md "${resized}. Up to twelve of each, demangled where possible:"
        md ''
        md '```'
        {
            comm -23 "${WORK}/p.names" "${WORK}/b.names" |
                awk 'NR <= 12' | sed 's/^/only in pipe:     /' | c++filt
            comm -13 "${WORK}/p.names" "${WORK}/b.names" |
                awk 'NR <= 12' | sed 's/^/only in backtick: /' | c++filt
            join "${WORK}/p.syms" "${WORK}/b.syms" |
                awk '$2 != $3 {printf "%+8d  %s\n", $3 - $2, $1}' |
                sort -k1,1n | awk 'NR <= 12' | c++filt
        } >>"${REPORT}"
        md '```'
        md ''
    done
}

# ---------------------------------------------------------------------------
# Axis 2: compile cost
#
# No deterministic counter is available here: perf_event_paranoid on this host
# blocks user-space instruction counts, so the metric is CPU time (user + sys),
# which is steadier than wall clock, taken as the best of REPS.
#
# Timing one variant to completion and then the other measures the machine's
# drift as much as the code -- an earlier run of this script had a pair with
# bit-identical objects come out 2x apart that way. So each repetition
# measures every variant in turn, and one of the variants is a control: the
# pipe source again, under a second name. The control's distance from the
# pipe measurement is that example's noise floor, taken at the same time and
# on the same machine as the number it qualifies.

PERF=0
if perf stat -x, -e instructions:u -- true 2>&1 | grep -q '^[0-9]'; then
    PERF=1
fi

# measure_once <source-dir> <flags> <variant-flag> <opt> -> "cpu wall rss"
measure_once() {
    local dir="$1" flags="$2" vflag="$3" opt="$4" u sec
    (
        cd "${dir}"
        # shellcheck disable=SC2086
        /usr/bin/time -o "${WORK}/time.txt" -f '%U %S %e %M' \
            "${PIN[@]}" "${CXX}" ${flags} "${opt}" -g0 -DNDEBUG "${vflag}" \
            -c tu.cpp -o tu.o
    ) >/dev/null 2>&1
    read -r u sec wall rss <"${WORK}/time.txt"
    echo "$(awk -v u="${u}" -v s="${sec}" 'BEGIN {printf "%.2f", u + s}') ${wall} ${rss}"
}

# keep_best <current> <candidate> -> whichever has the lower CPU time
keep_best() {
    [[ -z $1 ]] && {
        echo "$2"
        return
    }
    if awk -v a="${2%% *}" -v b="${1%% *}" 'BEGIN {exit !(a < b)}'; then
        echo "$2"
    else
        echo "$1"
    fi
}

# The two spellings do not include the same headers -- the backtick side pulls
# in smd/infix/pipe.hpp -- and both are dominated by <ranges> and <print>. A
# baseline TU with the same includes and an empty main makes that cost visible
# instead of leaving it inside the total.
baseline_for() {
    local src="$1" out="$2"
    grep '^#include' "${src}" >"${out}"
    echo 'int main() {}' >>"${out}"
}

# Total ExecuteCompiler first, so the same keep_best that ranks CPU seconds
# ranks these: a phase breakdown from one uncontrolled compile drifts as much
# as any other single measurement.
trace_once() {
    local dir="$1" flags="$2" vflag="$3"
    (
        cd "${dir}"
        # shellcheck disable=SC2086
        "${PIN[@]}" "${CXX}" ${flags} -O2 -g0 -DNDEBUG "${vflag}" \
            -ftime-trace -ftime-trace-granularity=100000 -c tu.cpp -o tu.o
    ) >/dev/null 2>&1
    jq -r '
        [.traceEvents[] | select(.name | startswith("Total "))]
        | map({key: .name, value: (.dur / 1000 | floor)}) | from_entries
        | [.["Total ExecuteCompiler"], .["Total Frontend"],
           .["Total InstantiateFunction"],
           .["Total CheckConstraintSatisfaction"], .["Total Backend"]]
        | map(. // 0) | join(" ")' "${dir}/tu.json"
}

compile_cost() {
    md '## Compile cost'
    md ''
    if [[ ${PERF} -eq 0 ]]; then
        md 'No instruction counter: `kernel.perf_event_paranoid` blocks user-space'
        md 'counts on this host, so these are times, not counts. `sudo sysctl'
        md '-w kernel.perf_event_paranoid=2` would make this axis deterministic'
        md 'too.'
    fi
    md ''
    md "Best of ${REPS} runs, pinned to one core, the variants interleaved --"
    md 'phase breakdowns included, so no column comes from a single compile.'
    md 'The control is the pipe source compiled a second time under another'
    md 'name: it is the same work, so its distance from the pipe column is what'
    md 'this machine contributes on its own. A pipe-to-backtick difference no'
    md 'larger than that is measurement, not code.'
    md ''
    md '| example | CPU s pipe | backtick | control | machine | headers pipe | backtick | frontend ms | instantiate ms | backend ms |'
    md '|---|---|---|---|---|---|---|---|---|---|'

    local pair name dir flags variant r
    local -a cleared=()
    local best_p best_b best_c best_bp best_bb best_tp best_tb
    local cpu_p cpu_b cpu_c cpu_bp cpu_bb spread verdict
    local fe_p inst_p constr_p be_p total_p fe_b inst_b constr_b be_b total_b

    for pair in "${PAIRS[@]}"; do
        name="${pair%%:*}"
        dir="${pair#*:}"
        flags="$(flags_for "${dir}/${name}.pipe.cpp")"

        stage "${dir}" "${name}" pipe
        stage "${dir}" "${name}" backtick
        mkdir -p "${WORK}/control" "${WORK}/base-pipe" "${WORK}/base-backtick"
        cp "${dir}/${name}.pipe.cpp" "${WORK}/control/tu.cpp"
        baseline_for "${dir}/${name}.pipe.cpp" "${WORK}/base-pipe/tu.cpp"
        baseline_for "${dir}/${name}.backtick.cpp" "${WORK}/base-backtick/tu.cpp"

        best_p='' best_b='' best_c='' best_bp='' best_bb='' best_tp='' best_tb=''
        for ((r = 0; r < REPS; ++r)); do
            best_p="$(keep_best "${best_p}" \
                "$(measure_once "${WORK}/pipe" "${flags}" -fno-backtick -O2)")"
            best_b="$(keep_best "${best_b}" \
                "$(measure_once "${WORK}/backtick" "${flags}" -fbacktick -O2)")"
            best_c="$(keep_best "${best_c}" \
                "$(measure_once "${WORK}/control" "${flags}" -fno-backtick -O2)")"
            best_bp="$(keep_best "${best_bp}" \
                "$(measure_once "${WORK}/base-pipe" "${flags}" -fno-backtick -O2)")"
            best_bb="$(keep_best "${best_bb}" \
                "$(measure_once "${WORK}/base-backtick" "${flags}" -fbacktick -O2)")"
            best_tp="$(keep_best "${best_tp}" \
                "$(trace_once "${WORK}/pipe" "${flags}" -fno-backtick)")"
            best_tb="$(keep_best "${best_tb}" \
                "$(trace_once "${WORK}/backtick" "${flags}" -fbacktick)")"
        done
        cpu_p="${best_p%% *}"
        cpu_b="${best_b%% *}"
        cpu_c="${best_c%% *}"
        cpu_bp="${best_bp%% *}"
        cpu_bb="${best_bb%% *}"

        # A gap counts only if it is twice the machine's own and not merely
        # the last digit of the clock. Anything else is not resolved here.
        verdict="$(awk -v p="${cpu_p}" -v b="${cpu_b}" -v c="${cpu_c}" 'BEGIN {
            d = (b > p ? b - p : p - b); n = (c > p ? c - p : p - c);
            printf "%s", (d > 2 * n && d > 0.10 ? "yes" : "no")
        }')"
        spread="$(awk -v p="${cpu_p}" -v c="${cpu_c}" \
            'BEGIN {d = (c > p ? c - p : p - c); printf "%.2f", d}')"

        read -r total_p fe_p inst_p constr_p be_p <<<"${best_tp}"
        read -r total_b fe_b inst_b constr_b be_b <<<"${best_tb}"

        md "| \`${name}\` | ${cpu_p} | ${cpu_b} | ${cpu_c} | ${spread} | ${cpu_bp} | ${cpu_bb} | ${fe_p} / ${fe_b} | ${inst_p} / ${inst_b} | ${be_p} / ${be_b} |"
        csv compile "${name}" -O2 \
            cpu_s_pipe "${cpu_p}" cpu_s_backtick "${cpu_b}" \
            cpu_s_control "${cpu_c}" control_spread_s "${spread}" \
            clears_noise "${verdict}" \
            max_rss_kb_pipe "${best_p##* }" max_rss_kb_backtick "${best_b##* }" \
            headers_only_cpu_s_pipe "${cpu_bp}" \
            headers_only_cpu_s_backtick "${cpu_bb}" \
            frontend_ms_pipe "${fe_p}" frontend_ms_backtick "${fe_b}" \
            instantiate_ms_pipe "${inst_p}" instantiate_ms_backtick "${inst_b}" \
            constraints_ms_pipe "${constr_p}" constraints_ms_backtick "${constr_b}" \
            backend_ms_pipe "${be_p}" backend_ms_backtick "${be_b}" \
            total_ms_pipe "${total_p}" total_ms_backtick "${total_b}"
        [[ ${verdict} == yes ]] && cleared+=("${name}")
    done
    md ''
    md 'The `machine` column is the pipe-to-control gap. A pipe-to-backtick'
    md 'gap counts only where it is twice that and at least 0.10s; anything'
    md 'smaller this host cannot resolve. Read the machine column first: if it'
    md 'is not near zero, the box was busy and the row says nothing.'
    md ''
    if [[ ${#cleared[@]} -eq 0 ]]; then
        md 'No example had a pipe-to-backtick gap larger than its own machine'
        md 'gap: on this host the spelling costs nothing to compile.'
    else
        md "Larger than the machine gap, and so worth reading: ${cleared[*]}."
        md 'Compare each against its two `headers` columns before crediting it'
        md 'to the spelling -- the backtick sources include one header more.'
    fi
    md ''
}

# ---------------------------------------------------------------------------
# Axis 3: constant evaluation
#
# -fconstexpr-steps bisected to the least value that still compiles. That is a
# count of constant-evaluation operations, not a time: it is identical on any
# machine, and it is the one number here that does not need a noise floor.

min_steps() {
    local src="$1" vflag="$2" n="$3" flags="$4"
    local lo=1 hi=1024 mid

    ok() {
        # shellcheck disable=SC2086
        "${CXX}" ${flags} "${vflag}" "-DSMD_EVAL_N=${n}" \
            "-fconstexpr-steps=$1" -fsyntax-only "${src}" 2>/dev/null
    }

    while ! ok "${hi}"; do
        lo=$((hi + 1))
        hi=$((hi * 4))
        [[ ${hi} -le 268435456 ]] || die "constexpr steps beyond 2^28 at n=${n}"
    done
    while [[ ${lo} -lt ${hi} ]]; do
        mid=$(((lo + hi) / 2))
        if ok "${mid}"; then hi="${mid}"; else lo=$((mid + 1)); fi
    done
    echo "${lo}"
}

consteval_cost() {
    local dir='' name=eval
    for pair in "${PAIRS[@]}"; do
        [[ ${pair%%:*} == eval ]] && dir="${pair#*:}"
    done
    [[ -n ${dir} ]] || return 0

    md '## Constant evaluation'
    md ''
    md 'The least `-fconstexpr-steps` that still compiles, bisected. A count,'
    md 'not a measurement: the same on any machine. `-DSMD_EVAL_N` resizes the'
    md 'work, so what matters is not the two numbers but whether they grow'
    md 'apart.'
    md ''
    md '| n | pipe | backtick | delta | per element |'
    md '|---|---|---|---|---|'

    local flags n p b per prev_p='' prev_n=''
    flags="$(flags_for "${dir}/${name}.pipe.cpp")"
    for n in ${SIZES}; do
        p="$(min_steps "${dir}/${name}.pipe.cpp" -fno-backtick "${n}" "${flags}")"
        b="$(min_steps "${dir}/${name}.backtick.cpp" -fbacktick "${n}" "${flags}")"
        if [[ -n ${prev_p} ]]; then
            per="$(awk -v d="$((p - prev_p))" -v e="$((n - prev_n))" \
                'BEGIN {printf "%.1f", d / e}')"
        else
            per='--'
        fi
        md "| ${n} | ${p} | ${b} | $((b - p)) | ${per} |"
        csv consteval "${name}" "${n}" steps_pipe "${p}" \
            steps_backtick "${b}" delta "$((b - p))"
        prev_p="${p}"
        prev_n="${n}"
    done
    md ''
}

# ---------------------------------------------------------------------------

mkdir -p "${OUTDIR}"
: >"${CSV}"
: >"${REPORT}"
echo "axis,example,key,metric,value" >>"${CSV}"

md "# What the two spellings cost"
md ''
md "Generated by \`scripts/compare.sh\`. Do not edit."
md ''
md '```'
md "compiler  $("${CXX}" --version | awk 'NR == 1')"
md "host      $(uname -sr), $(nproc) cores"
md "date      $(date -u '+%Y-%m-%d %H:%M UTC')"
names=()
for pair in "${PAIRS[@]}"; do names+=("${pair%%:*}"); done
md "examples  ${names[*]}"
md '```'
md ''
md 'Both halves of a pair are compiled by the same compiler at the same'
md 'settings, from a file of the same name, differing only in the spelling of'
md 'their calls and in `-fbacktick` against `-fno-backtick`.'
md ''

case "${ONLY}" in
    '') codegen; compile_cost; consteval_cost ;;
    codegen) codegen ;;
    compile) compile_cost ;;
    consteval) consteval_cost ;;
esac

# Trailing blank lines fail markdownlint and the end-of-file hook rewrites
# them, which would make a generated file dirty the moment it is written.
printf '%s\n' "$(cat "${REPORT}")" >"${WORK}/report.md"
mv "${WORK}/report.md" "${REPORT}"

echo "compare.sh: wrote ${REPORT}"
echo "compare.sh: wrote ${CSV}"
