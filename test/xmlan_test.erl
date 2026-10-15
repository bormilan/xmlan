-module(xmlan_test).

-include_lib("eunit/include/eunit.hrl").

% Adapted from Signerl's XML contracts; see NOTICE for source and licensing.
add_new_element_preserves_content_test() ->
    Root = {<<"library">>, [{<<"id">>, "112233"}], [" before ", {<<"book">>, [], []}, " after "]},
    New = {<<"book">>, [{<<"id">>, "4"}], [{<<"title">>, [], ["My new book"]}]},
    Expected =
        {<<"library">>, [{<<"id">>, "112233"}], [" before ", {<<"book">>, [], []}, " after ", New]},
    ?assertEqual(Expected, xmlan:add_new_element(New, Root)).

add_new_element_to_empty_tree_test() ->
    Child = {<<"child">>, [], []},
    ?assertEqual({<<"root">>, [], [Child]}, xmlan:add_new_element(Child, {<<"root">>, [], []})).

single_text_test_() ->
    [
        {Name, ?_assertEqual(Expected, xmlan:single_text({<<"tag">>, [], Content}))}
     || {Name, Content, Expected} <- [
            {"binary", [<<"abc">>], {ok, <<"abc">>}},
            {"character list", ["abc"], {ok, <<"abc">>}},
            {"Unicode character list", ["café ő 東京 😀"], {ok, <<"café ő 東京 😀"/utf8>>}},
            {"UTF-8 binary", [<<"café ő 東京 😀"/utf8>>], {ok, <<"café ő 東京 😀"/utf8>>}},
            {"empty binary value", [<<>>], {ok, <<>>}},
            {"empty list value", [[]], {ok, <<>>}},
            {"no children", [], {error, not_found}},
            {"multiple text nodes", ["a", "b"], {error, not_found}},
            {"element child", [{<<"child">>, [], []}], {error, not_found}}
        ]
    ].

attribute_values_are_preserved_test_() ->
    [
        {Name, fun() ->
            Attrs = [{<<"value">>, Value}],
            ?assertEqual({ok, Value}, xmlan:attr_value(<<"value">>, Attrs)),
            ?assertEqual(Value, xmlan:attr_value_or_undefined(<<"value">>, Attrs))
        end}
     || {Name, Value} <- [
            {"character list", "café"},
            {"UTF-8 binary", <<"café"/utf8>>},
            {"integer", -42},
            {"atom", hello},
            {"explicit undefined", undefined}
        ]
    ].

missing_attribute_test() ->
    ?assertEqual({error, missing_attribute}, xmlan:attr_value(<<"absent">>, [])),
    ?assertEqual(undefined, xmlan:attr_value_or_undefined(<<"absent">>, [])).

attribute_names_are_exact_test() ->
    Attrs = [{<<"p:value">>, "namespaced"}, {<<"Value">>, "uppercase"}],
    ?assertEqual({error, missing_attribute}, xmlan:attr_value(<<"value">>, Attrs)),
    ?assertEqual(undefined, xmlan:attr_value_or_undefined(<<"value">>, Attrs)).

first_duplicate_attribute_wins_test() ->
    Attrs = [{<<"value">>, "first"}, {<<"value">>, "second"}],
    ?assertEqual({ok, "first"}, xmlan:attr_value(<<"value">>, Attrs)),
    ?assertEqual("first", xmlan:attr_value_or_undefined(<<"value">>, Attrs)).
