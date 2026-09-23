// src/examples/ranges/calendar.backtick.cpp                         -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// calendar.pipe.cpp with the calls spelled infix. See that file for what the
// program is and where it comes from.
//
// Of the nine adaptor applications here, seven are binary and convert
// directly: chunk_by, transform, chunk. Two are views::join, which takes
// nothing beyond its range and so keeps the `pipe` helper, as does
// ranges::to. The top-level pipeline reads the same way it did, one stage
// per line, because the backtick binds tighter than everything else -- no
// stage needed a parenthesis.
//
// pipe is written qualified inside the generic lambdas. They are templates,
// and the GCC prototype rejects an unqualified slot name in a dependent
// context: it looks the name up only by ADL at the point of instantiation
// and discards the ordinary lookup from the definition context, and pipe is
// a variable, so ADL finds nothing. Clang accepts it on both tracks. In main,
// which is not a template, the using-declaration is enough. Recorded as
// DEV-G11; see docs/divergences/dev-g11-dependent-slot.cpp.

#include <smd/infix/pipe.hpp>

#include <chrono>
#include <cstddef>
#include <format>
#include <print>
#include <ranges>
#include <string>
#include <string_view>
#include <vector>

namespace views = std::views;
using namespace std::chrono;
using smd::infix::pipe;

namespace {

constexpr std::size_t col_width = 22;
constexpr std::size_t month_lines = 7; // the title, then six week lines
constexpr std::size_t per_line = 3;

// boost::format's %|=n| puts the odd space on the left; std::format's ^ puts
// it on the right. Centre by hand so the output matches the original.
std::string center(std::string_view s, std::size_t w) {
    const auto pad = w > s.size() ? w - s.size() : 0;
    const auto left = pad - pad / 2;
    return std::string(left, ' ') + std::string{s} +
           std::string(pad - left, ' ');
}

std::string format_day(sys_days d) {
    return std::format("{:>3}", unsigned{year_month_day{d}.day()});
}

std::string month_title(sys_days d) {
    return center(std::format("{:%B}", year_month_day{d}.month()), col_width);
}

// In:  nothing.  Out: range<sys_days>, every day of the years [start, stop).
auto dates(int start_year, int stop_year) {
    const sys_days first = sys_days{year{start_year} / January / 1};
    const sys_days last = sys_days{year{stop_year} / January / 1};
    return views::iota(0, (last - first).count()) `views::transform`
        [first](int i) { return first + days{i}; };
}

const auto same_month = [](sys_days a, sys_days b) {
    return year_month_day{a}.month() == year_month_day{b}.month();
};

// A week starts on Sunday, so b joins a's chunk unless b is a Sunday.
const auto same_week = [](sys_days, sys_days b) {
    return weekday{b} != Sunday;
};

// In:  range<sys_days>: one week.  Out: string, one line of a month.
const auto format_week = [](auto week) {
    const auto lead =
        std::string(weekday{*std::ranges::begin(week)}.c_encoding() * 3u, ' ');
    const auto text = week `views::transform` format_day `smd::infix::pipe`
        views::join `smd::infix::pipe` std::ranges::to<std::string>();

    auto line = lead + text;
    line.resize(col_width, ' ');
    return line;
};

// In:  range<sys_days>: one month.  Out: vector<string>, the month's lines,
// always month_lines of them so that months laid side by side stay aligned.
const auto layout_month = [](auto month) {
    auto lines = month `views::chunk_by` same_week `views::transform`
        format_week `smd::infix::pipe` std::ranges::to<std::vector>();

    lines.insert(lines.begin(), month_title(*std::ranges::begin(month)));
    lines.resize(month_lines, std::string(col_width, ' '));
    return lines;
};

// In:  range<vector<string>>: months side by side.
// Out: range<range<string>>: the same text by row rather than by month.
const auto transpose = [](auto months) {
    return views::iota(0uz, month_lines) `views::transform`
        [months](std::size_t row) {
            return months `views::transform`
                [row](const std::vector<std::string> &m) { return m[row]; };
        };
};

// In:  range<string>: one row across the side-by-side months.
// Out: string, the printable line.
const auto join_row = [](auto row) {
    auto line = row `smd::infix::pipe` views::join `smd::infix::pipe`
        std::ranges::to<std::string>();
    while (!line.empty() && line.back() == ' ') {
        line.pop_back();
    }
    return line;
};

} // namespace

// ade28340-6ad4-4580-8011-d001a7bf4bf4
int main() {
    auto calendar = dates(2015, 2016)
        // Group the dates by month:
        `views::chunk_by` same_month
        // Format each month into a block of lines:
        `views::transform` layout_month
        // Group the months that belong side by side:
        `views::chunk` per_line
        // Read those months by row instead of by month:
        `views::transform` transpose
        // Ungroup the side-by-side months:
        `pipe` views::join
        // Join each row into one printable line:
        `views::transform` join_row;

    for (const auto &line : calendar) {
        std::println("{}", line);
    }
}
// ade28340-6ad4-4580-8011-d001a7bf4bf4 end
