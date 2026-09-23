// src/smd/infix/pipe.hpp                                            -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#ifndef INCLUDED_SMD_INFIX_PIPE
#define INCLUDED_SMD_INFIX_PIPE

#include <functional>
#include <utility>

namespace smd::infix {

// 17cc4d61-f8c7-460f-880e-6f91fcf875b5
// `pipe` applies a unary callable to a value, spelled infix.
//
// Most range and sender adaptors take their subject as the first argument --
// `views::filter(r, pred)`, `then(sndr, fn)` -- so the backtick spells them
// directly: `r `views::filter` pred`. The ones that take no argument beyond
// the subject have no such spelling, because a backtick operator is exactly
// binary. `views::join` and `sync_wait` are already the whole callable, so
// there is no second operand to write.
//
// `pipe` supplies one. `x `pipe` f` is `f(x)`, which keeps a niladic stage in
// the same left-to-right chain as its neighbours instead of forcing the chain
// to be turned inside out into a call.
inline constexpr auto pipe =
    []<typename X, typename F>(X &&x, F &&f) -> decltype(auto) {
    return std::invoke(std::forward<F>(f), std::forward<X>(x));
};
// 17cc4d61-f8c7-460f-880e-6f91fcf875b5 end

} // namespace smd::infix

#endif // INCLUDED_SMD_INFIX_PIPE
