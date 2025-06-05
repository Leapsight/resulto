%% =============================================================================
%%  resulto.erl -
%%  Copyright (c) 2024-2025 Leapsight. All rights reserved.
%%  Copyright 2018, Louis Pilfold <louis@lpil.uk>.
%%
%%  Licensed under the Apache License, Version 2.0 (the "License");
%%  you may not use this file except in compliance with the License.
%%  You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%%  Unless required by applicable law or agreed to in writing, software
%%  distributed under the License is distributed on an "AS IS" BASIS,
%%  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%  See the License for the specific language governing permissions and
%%  limitations under the License.
%% =============================================================================

-module(resulto).

-if(?OTP_RELEASE >= 27).
    -define(MODULEDOC(Str), -moduledoc(Str)).
    -define(DOC(Str), -doc(Str)).
-else.
    -define(MODULEDOC(Str), -compile([])).
    -define(DOC(Str), -compile([])).
-endif.

-moduledoc #{format => "text/markdown"}.
?MODULEDOC("""
Result represents the result of something that may succeed or not:
* `{ok, any()}` means it was successful,
* `{error, any()}` means it was not.

Borrowed from the elegant Gleam's [result]
(https://hexdocs.pm/gleam_stdlib/gleam/result.html) module.
""").

?DOC("""
Represents a value that is either a success (`ok`, `{ok, Value}`) or a
failure (`{error, Reason}`).
""").
-type t()       ::  ok | ok() | error().

?DOC("A successful result with its associated value").
-type ok()      ::  ok(any()).

?DOC("A failure result with its associated reason").
-type error()   ::  error(any()).
-type ok(T)     ::  {ok, T}.
-type error(T)  ::  {error, T}.


-export(['try'/2]).
-export([all/1]).
-export([error/1]).
-export([flatten/1]).
-export([is_error/1]).
-export([is_ok/1]).
-export([lazy_or/2]).
-export([lazy_unwrap/2]).
-export([map/2]).
-export([map_error/2]).
-export([ok/1]).
-export([or_else/2]).
-export([partition/1]).
-export([raise_or/1]).
-export([raise_or_unwrap/1]).
-export([replace/2]).
-export([replace_error/2]).
-export([result/1]).
-export([then/2]).
-export([then_both/3]).
-export([then_recover/2]).
-export([try_both/3]).
-export([try_recover/2]).
-export([undefined_error/1]).
-export([unwrap/1]).
-export([unwrap/2]).
-export([unwrap_both/1]).
-export([unwrap_error/2]).
-export([values/1]).


-compile({no_auto_import, [error/1]}).



%% =============================================================================
%% API
%% =============================================================================



?DOC("Creates a successful result.").
-spec ok(Value :: any()) -> ok().

ok(Value) ->
    {ok, Value}.


?DOC("Creates a failed result.").
-spec error(Error :: any()) -> error().

error(Error) ->
    {error, Error}.


?DOC("""
Wraps a term in a result.

If the term is already a result, it is returned as-is. If the term is `ok`,
it returns `ok`; otherwise it wraps the term in `{ok, Term}`.
""").
-spec result(Term :: any()) -> t().

result(ok) -> ok;
result({ok, _} = T) -> T;
result({error, _} = T) -> T;
result(Term) -> ok(Term).



?DOC("""
Combines a list of results into a single result.

If all elements in the list are `ok` then returns an `ok` holding the list of
values. If any element is an error then returns the first `error`.
""").
-spec all([t()]) -> t().

all(Results) when is_list(Results) ->
    try
        Values = lists:foldl(
            fun
                ({ok, Value}, Acc) ->
                    [Value | Acc];
                ({error, _} = Result, _) ->
                    throw(Result)
            end,
            [],
            Results
        ),
        {ok, lists:reverse(Values)}

    catch
        throw:{error, _} = Result ->
            Result
    end.


?DOC("""
Flattens nested results (e.g., `{ok, {ok, Value}}`) into a single-layer result.
""").
-spec flatten(t()) -> t().

flatten({ok, {ok, _} = Result}) ->
    flatten(Result);

flatten({ok, {error, _} = Result}) ->
    flatten(Result);

flatten({error, {error, _} = Result}) ->
    flatten(Result);

flatten({ok, _} = Result) ->
    Result;

flatten({error, _} = Result) ->
    Result.


?DOC("Returns `true` if the result is an error.").
-spec is_error(t()) -> boolean().

is_error(ok) -> false;
is_error({ok, _}) -> false;
is_error({error, _}) -> true.


?DOC("Returns `true` if the result is an successful.").
-spec is_ok(t()) -> boolean().

is_ok(ok) -> true;
is_ok({ok, _}) -> true;
is_ok({error, _}) -> false.


?DOC("""
Returns the original result if it's `ok`, otherwise calls the provided function
to return an alternative result.
""").
-spec lazy_or(Result :: t(), Fun :: fun(() -> t())) -> t().

lazy_or(ok = Result, Fun) when is_function(Fun, 0) ->
    Result;

lazy_or({ok, _} = Result, Fun) when is_function(Fun, 0) ->
    Result;

lazy_or({error, _}, Fun) when is_function(Fun, 0) ->
    Fun().


?DOC("""
Returns the value of the result if it's `ok`, otherwise calls the fallback
function.
""").
-spec lazy_unwrap(Result :: t(), Fun :: fun(() -> t())) -> any().

lazy_unwrap(ok, Fun) when is_function(Fun, 0) ->
    undefined;

lazy_unwrap({ok, Value}, Fun) when is_function(Fun, 0) ->
    Value;

lazy_unwrap({error, _}, Fun) when is_function(Fun, 0) ->
    Fun().

?DOC("""
Returns the result if successful, otherwise raises the error.
""").
-spec raise_or(t()) -> ok() | no_return().

raise_or(ok = Result) ->
    Result;

raise_or({ok, _} = Result) ->
    Result;

raise_or({error, Reason}) ->
    erlang:error(Reason).


?DOC("Extracts the `ok` value or raises the error if not present.").
-spec raise_or_unwrap(t()) -> any() | no_return().

raise_or_unwrap(ok) ->
    undefined;

raise_or_unwrap({ok, Value}) ->
    Value;

raise_or_unwrap({error, Reason}) ->
    erlang:error(Reason).

?DOC("""
Applies a function to the value inside `ok`. Errors are returned unchanged.
""").
-spec map(Result :: t(), fun((any()) -> any())) -> error() | any().

map(ok, Fun) when is_function(Fun, 1) ->
    {ok, Fun(undefined)};

map({ok, Value}, Fun) when is_function(Fun, 1) ->
    {ok, Fun(Value)};

map({error, _} = Result, Fun) when is_function(Fun, 1) ->
    Result.


?DOC("""
Applies a function to the value inside `error`. Successful results are
returned unchanged.
""").
-spec map_error(Result :: t(), fun((any()) -> any())) -> error() | any().
map_error(ok = Result, Fun) when is_function(Fun, 1) ->
    Result;

map_error({ok, _} = Result, Fun) when is_function(Fun, 1) ->
    Result;

map_error({error, Error}, Fun) when is_function(Fun, 1) ->
    {error, Fun(Error)}.


?DOC("Converts any error to `{error, undefined}`.").
-spec undefined_error(Result :: t()) -> ok() | error(undefined).

undefined_error(ok = Result) ->
    Result;

undefined_error({ok, _} = Result) ->
    Result;

undefined_error({error, _}) ->
    error(undefined).


?DOC("Returns the first result if successful, otherwise the second.").
-spec or_else(First :: t(), Second :: t()) -> t().

or_else(ok = Result, _) -> Result;
or_else(_, ok = Result) -> Result;
or_else({ok, _} = Result, _) -> Result;
or_else(_, {ok, _} = Result) -> Result;
or_else(_, {error, _} = Result) -> Result.


?DOC("""
Separates a list of results into a tuple with all successes and all errors.
The lists are in reverse order of their appearance.
""").
-spec partition(Results :: [t()]) -> {[any()], [any()]} | no_return().

partition(Results) ->
    lists:foldl(
        fun
            (ok, Acc) ->
                Acc;

            ({ok, Value}, {Values, Errors}) ->
                {[Value | Values], Errors};

            ({error, Error}, {Values, Errors}) ->
                {Values, [Error | Errors]};

            (_, _) ->
                error(badarg)
        end,
        {[], []},
        Results
    ).


?DOC("Replaces the value inside a successful result.").
-spec replace(Result :: t(), Value :: any()) -> t().

replace(ok, Value) -> {ok, Value};
replace({ok, _}, Value) -> {ok, Value};
replace({error, _} = Result, _) -> Result.


?DOC("Replaces the value inside a failed result.").
-spec replace_error(Result :: t(), Error :: any()) -> t().

replace_error(ok = Result, _) -> Result;
replace_error({ok, _} = Result, _) -> Result;
replace_error({error, _}, Error) -> {error, Error}.


?DOC("An alias for `try/2`.").
-spec then(Result :: t(), Fun :: fun((any()) -> t())) -> t() | no_return().

then(Result, Fun) -> 'try'(Result, Fun).


?DOC("An alias for `try_recover/2`.").
-spec then_recover(Result :: t(), Fun :: fun((any()) -> t())) ->
    t() | no_return().

then_recover(Result, Fun) -> try_recover(Result, Fun).


?DOC("An alias for `try_both/2`.").
-spec then_both(
    Result :: t(),
    Fun :: fun((any()) -> t()),
    Fun :: fun((any()) -> t())) -> t() | no_return().

then_both(Result, Fun, RecoverFun) -> try_both(Result, Fun, RecoverFun).


?DOC("""
Applies a function to the value inside a successful result, returning its result.
Errors are returned unchanged.
""").
-spec 'try'(Result :: t(), Fun :: fun((any()) -> t())) -> t() | no_return().

'try'(ok = Result, Fun) when is_function(Fun, 1) ->
    eval_result(Result, Fun);

'try'({ok, _} = Result, Fun) when is_function(Fun, 1) ->
    eval_result(Result, Fun);

'try'({error, _} = Result, Fun) when is_function(Fun, 1) ->
    Result.


?DOC("""
Applies a function to the value inside an error, returning its result.
Success values are returned unchanged.
""").
-spec try_recover(Result :: t(), Fun :: fun((any()) -> t())) ->
    t() | no_return().

try_recover(ok = Result, Fun) when is_function(Fun, 1) ->
    Result;

try_recover({ok, _} = Result, Fun) when is_function(Fun, 1) ->
    Result;

try_recover({error, _} = Result, Fun) when is_function(Fun, 1) ->
    eval_result(Result, Fun).


?DOC("""
Applies a function to the value inside a successful result.
If it's an error, applis a recovery function instead.
""").
-spec try_both(
    Result :: t(),
    Fun :: fun((any()) -> t()),
    Fun :: fun((any()) -> t())) -> t() | no_return().

try_both(ok = Result, Fun, _) ->
    'try'(Result, Fun);

try_both({ok, _} = Result, Fun, _) ->
    'try'(Result, Fun);

try_both({error, _} = Result, _, RecoverFun) ->
    try_recover(Result, RecoverFun).


?DOC("""
Returns the `ok` value or `undefined` if the result is an error.
""").
-spec unwrap(Result :: t()) -> any().
unwrap(Result) ->
    unwrap(Result, undefined).


?DOC("""
Returns the `ok` value or the given default value if it's an error.
""").
-spec unwrap(Result :: t(), Default :: any()) -> any().

unwrap(ok, _) -> undefined;
unwrap({ok, Value}, _) -> Value;
unwrap({error, _}, Default) -> Default.

?DOC("""
Returns either the `ok` or `error` value, whichever is present.
""").
-spec unwrap_both(Result :: t()) -> any().

unwrap_both(ok) -> undefined;
unwrap_both({ok, Value}) -> Value;
unwrap_both({error, Error}) -> Error.


?DOC("""
Returns the `error` value or the default if it's an `ok`.
""").
-spec unwrap_error(Result :: t(), Default :: any()) -> any().

unwrap_error(ok, Default) -> Default;
unwrap_error({ok, _}, Default) -> Default;
unwrap_error({error, Error}, _) -> Error.


?DOC("""
Returns all the values inside `ok` results from a list of results.
""").
-spec values(Results :: [t()]) -> [any()].

values(Results) ->
    lists:filtermap(
        fun
            ({ok, Value}) -> {true, Value};
            (_) -> false
        end,
        Results
    ).



%% =============================================================================
%% PRIVATE
%% =============================================================================



eval_result(Result0, Fun) when is_function(Fun, 0) ->
    case Fun() of
        ok = Result ->
            Result;
        {ok, _} = Result ->
            Result;
        {error, _} = Result ->
            Result;
        _ ->
            not_a_result([Result0, Fun], 2)
    end;

eval_result(ok, Fun) when is_function(Fun, 1) ->
    case Fun(undefined) of
        ok = Result ->
            Result;
        {ok, _} = Result ->
            Result;
        {error, _} = Result ->
            Result;
        _ ->
            not_a_result([ok, Fun], 2)
    end;

eval_result(Result0, Fun) when is_function(Fun, 1) ->
    case Fun(element(2, Result0)) of
        ok = Result ->
            Result;
        {ok, _} = Result ->
            Result;
        {error, _} = Result ->
            Result;
        _ ->
            not_a_result([Result0, Fun], 2)
    end.


not_a_result(Args, Pos) ->
    erlang:error(
        badarg,
        Args,
        [
            {error_info, #{
                module => ?MODULE,
                cause => #{
                    Pos => "Function should return a 'bondy_result:t()'."
                },
                meta => #{}
            }}
        ]
    ).




%% =============================================================================
%% EUNIT
%% =============================================================================

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

all_test_() ->
    [
        ?_assertEqual(ok([1, 2]), all([ok(1), ok(2)])),
        ?_assertEqual(error(foo), all([ok(1), ok(2), error(foo)])),
        ?_assertEqual(error(foo), all([ok(1), ok(2), error(foo), error(bar)])),
        ?_assertEqual(error(foo), all([error(foo), error(bar)])),

        ?_assertError(function_clause, all([foo]))
    ].


flatten_test_() ->
    [
        ?_assertEqual(ok(foo), flatten(ok(ok(foo)))),
        ?_assertEqual(ok(foo), flatten(ok(ok(ok(ok(foo)))))),
        ?_assertEqual(error(foo), flatten(error(error(foo)))),
        ?_assertEqual(error(foo), flatten(error(error(error(error(foo)))))),
        ?_assertEqual(error(foo), flatten(ok(error(foo)))),

        ?_assertError(function_clause, flatten(foo))
    ].


typecheck_test_() ->
    [
        ?_assert(is_ok(ok(foo))),
        ?_assertEqual(false, is_ok(error(foo))),
        ?_assert(is_error(error(foo))),
        ?_assertEqual(false, is_error(ok(foo))),

        ?_assertError(function_clause, is_ok(foo)),
        ?_assertError(function_clause, is_error(foo))
    ].


lazy_or_test_() ->
    [
        ?_assertEqual(ok(1), lazy_or(ok(1), fun() -> ok(2) end)),
        ?_assertEqual(ok(1), lazy_or(ok(1), fun() -> error(foo) end)),
        ?_assertEqual(ok(1), lazy_or(error(foo), fun() -> ok(1) end)),
        ?_assertEqual(error(bar), lazy_or(error(foo), fun() -> error(bar) end)),
        ?_assertEqual(ok(1), lazy_or(ok(1), fun() -> not_a_result end)),

        ?_assertEqual(not_a_result, lazy_or(error(foo), fun() -> not_a_result end)),
        ?_assertError(function_clause, lazy_or(ok(1), not_a_fun)),
        ?_assertError(function_clause, lazy_or(error(foo), not_a_fun))
    ].


lazy_unwrap_test_() ->
    [
        ?_assertEqual(1, lazy_unwrap(ok(1), fun() -> 2 end)),
        ?_assertEqual(2, lazy_unwrap(error(foo), fun() -> 2 end)),
        ?_assertError(function_clause, lazy_unwrap(ok(1), not_a_fun)),
        ?_assertError(function_clause, lazy_unwrap(error(foo), not_a_fun))
    ].

map_test_() ->
    [
        ?_assertEqual(ok(2), map(ok(1), fun(X) -> X + 1 end)),
        ?_assertEqual(error(foo), map(error(foo), fun(X) -> X + 1 end)),
        ?_assertError(function_clause, map(ok(1), not_a_fun)),
        ?_assertError(function_clause, map(error(foo), not_a_fun))
    ].

undefined_error_test_() ->
    [
        ?_assertEqual(ok(1), undefined_error(ok(1))),
        ?_assertEqual(error(undefined), undefined_error(error(foo)))
    ].


or_test_() ->
    [
        ?_assertEqual(ok(1), or_else(ok(1), ok(2))),
        ?_assertEqual(ok(1), or_else(ok(1), error(foo))),
        ?_assertEqual(ok(2), or_else(error(foo), ok(2))),
        ?_assertEqual(error(bar), or_else(error(foo), error(bar)))
    ].


partition_test_() ->
    [
        ?_assertEqual(
            {[2, 1], [bar, foo]},
            partition([ok(1), error(foo), ok(2), error(bar)])
        )
    ].


replace_test_() ->
    [
        ?_assertEqual(ok(2), replace(ok(1), 2)),
        ?_assertEqual(error(foo), replace(error(foo), 2))
    ].

replace_error_test_() ->
    [
        ?_assertEqual(ok(1), replace_error(ok(1), bar)),
        ?_assertEqual(error(bar), replace_error(error(foo), bar))
    ].


then_try_test_() ->
    [
        ?_assertEqual(ok(2), then(ok(1), fun(X) -> ok(X + 1) end)),
        ?_assertEqual(ok(2), 'try'(ok(1), fun(X) -> ok(X + 1) end)),
        ?_assertEqual(error("Oh no"), then(ok(1), fun(_) -> error("Oh no") end)),
        ?_assertEqual(error("Oh no"), 'try'(ok(1), fun(_) -> error("Oh no") end))
    ].

try_recover_test_() ->
    [

        ?_assertEqual(ok(1), try_recover(ok(1), fun(_) -> error("Oh no") end)),
        ?_assertEqual(ok(2), try_recover(error(1), fun(X) -> ok(X + 1) end)),
        ?_assertEqual(
            error("Oh no"), try_recover(error(1), fun(_) -> error("Oh no") end)
        )
    ].

unwrap_test_() ->
    [
        ?_assertEqual(1, unwrap(ok(1), 2)),
        ?_assertEqual(2, unwrap(error(1), 2))
    ].


unwrap_both_test_() ->
    [
        ?_assertEqual(1, unwrap_both(ok(1))),
        ?_assertEqual(1, unwrap_both(error(1)))
    ].


unwrap_error_test_() ->
    [
        ?_assertEqual(2, unwrap_error(ok(1), 2)),
        ?_assertEqual(1, unwrap_error(error(1), 2))
    ].


values_test_() ->
    [
        ?_assertEqual([1, 2], values([ok(1), ok(2), error(foo)])),
        ?_assertEqual([], values([error(foo)]))
    ].

-endif.
