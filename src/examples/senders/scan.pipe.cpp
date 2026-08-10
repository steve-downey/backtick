// src/examples/senders/scan.pipe.cpp                                -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// The asynchronous inclusive scan from P2300, in the idiom the paper writes
// it in, with bulk updated to its current signature. scan.backtick.cpp is
// the same pipeline with the calls spelled infix; the two must print the
// same thing.

#include <examples/senders/thread_context.hpp>

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

    return ex::just(std::move(partials)) | ex::continues_on(sch) |
           ex::bulk(ex::par, tile_count,
                    [=](std::size_t i, std::vector<double> &partials) {
                        const auto start = i * tile_size;
                        const auto end =
                            std::min(input.size(), (i + 1) * tile_size);
                        partials[i + 1] = *--std::inclusive_scan(
                            input.begin() + start, input.begin() + end,
                            output.begin() + start);
                    }) |
           ex::then([](std::vector<double> &&partials) {
               std::inclusive_scan(partials.begin(), partials.end(),
                                   partials.begin());
               return std::move(partials);
           }) |
           ex::bulk(
               ex::par, tile_count,
               [=](std::size_t i, std::vector<double> &partials) {
                   const auto start = i * tile_size;
                   const auto end = std::min(input.size(), (i + 1) * tile_size);
                   std::for_each(output.begin() + start, output.begin() + end,
                                 [&](double &e) { e = partials[i] + e; });
               }) |
           ex::then([=](std::vector<double> &&) { return output; });
}

} // namespace

// bbcb3b7a-3101-4960-ab1c-f0b8bee32b6e
int main() {
    examples::thread_context pool{"pool"};

    const std::vector<double> input(16, 1.0);
    std::vector<double> output(input.size());

    auto scan = async_inclusive_scan(pool.scheduler(), input, output, 0.0, 4);

    auto [result] = ex::sync_wait(std::move(scan)).value();
    for (double e : result) {
        std::print("{} ", e);
    }
    std::print("\n");
}
// bbcb3b7a-3101-4960-ab1c-f0b8bee32b6e end
