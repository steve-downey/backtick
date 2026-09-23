// src/examples/senders/scan.backtick.cpp                            -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// scan.pipe.cpp with the calls spelled infix. This is the example that shows
// where the operator stops.
//
// continues_on and then are binary, so they convert directly. bulk is not:
// bulk(sndr, policy, shape, f) takes four arguments, and a backtick operator
// is exactly binary. There is no infix spelling of a four-argument call and
// this proposal does not invent one.
//
// So bulk keeps its closure and the `pipe` helper carries it. That is the
// honest shape of the result: the pipe idiom survives exactly where the
// arity does not fit, and only there. The other option is a plain call,
// ex::bulk(sndr, ex::par, tile_count, f), which costs the chain -- the
// pipeline has to be turned inside out around it.
//
// The slot is written qualified as smd::infix::pipe rather than relying on
// a using-declaration. async_inclusive_scan is a template, and the GCC
// prototype rejects an unqualified slot name in a dependent context: it
// looks the name up only by ADL at the point of instantiation and discards
// the ordinary lookup from the definition context. pipe is a variable, so
// ADL finds nothing. Clang accepts it on both tracks. Recorded as DEV-G11.

#include <examples/senders/thread_context.hpp>

#include <smd/infix/pipe.hpp>

#include <beman/execution/execution.hpp>

#include <algorithm>
#include <numeric>
#include <print>
#include <span>
#include <tuple>
#include <utility>
#include <vector>

namespace ex = beman::execution;

namespace {

auto async_inclusive_scan(ex::scheduler auto sch, std::span<const double> input,
                          std::span<double> output, double init,
                          std::size_t tile_count) {
    const std::size_t tile_size = (input.size() + tile_count - 1) / tile_count;

    std::vector<double> partials(tile_count + 1);
    partials[0] = init;

    return ex::just(std::move(partials)) `ex::continues_on`
        sch `smd::infix::pipe`
        ex::bulk(ex::par, tile_count,
                 [=](std::size_t i, std::vector<double> &partials) {
                     const auto start = i * tile_size;
                     const auto end =
                         std::min(input.size(), (i + 1) * tile_size);
                     partials[i + 1] = *--std::inclusive_scan(
                         input.begin() + start, input.begin() + end,
                         output.begin() + start);
                 }) `ex::then` [](std::vector<double> &&partials) {
            std::inclusive_scan(partials.begin(), partials.end(),
                                partials.begin());
            return std::move(partials);
        } `smd::infix::pipe`
        ex::bulk(ex::par, tile_count,
                 [=](std::size_t i, std::vector<double> &partials) {
                     const auto start = i * tile_size;
                     const auto end =
                         std::min(input.size(), (i + 1) * tile_size);
                     std::for_each(output.begin() + start, output.begin() + end,
                                   [&](double &e) { e = partials[i] + e; });
                 }) `ex::then` [=](std::vector<double> &&) { return output; };
}

} // namespace

// b38693ad-2fc4-46f8-bda3-70efeee491bd
int main() {
    examples::thread_context pool{"pool"};

    const std::vector<double> input(16, 1.0);
    std::vector<double> output(input.size());

    auto scan = async_inclusive_scan(pool.scheduler(), input, output, 0.0, 4);

    auto [result] = (std::move(scan) `smd::infix::pipe` ex::sync_wait).value();
    for (double e : result) {
        std::print("{} ", e);
    }
    std::print("\n");
}
// b38693ad-2fc4-46f8-bda3-70efeee491bd end
