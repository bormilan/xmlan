-module(xmlan_consumer).

-include_lib("stdlib/include/assert.hrl").

-export([run/0, tree/0]).

-spec tree() -> xmlan:simplified_xml().
tree() ->
    {<<"root">>, [{<<"value">>, <<"café"/utf8>>}], [<<"東京"/utf8>>]}.

-spec metadata() -> {xmlan:attribute_value(), xmlan:expanded_name()}.
metadata() ->
    {<<"café"/utf8>>, {<<"urn:example">>, <<"root">>}}.

-spec run() -> {xmlan:simplified_xml(), xmlan:expanded_xml(), xmlan:namespace_context()}.
run() ->
    {Name, Attrs, _} = Tree = tree(),
    ?assertEqual(<<"root">>, Name),
    ?assertEqual({ok, <<"café"/utf8>>}, xmlan:attr_value(<<"value">>, Attrs)),
    ?assertEqual(<<"café"/utf8>>, xmlan:attr_value_or_undefined(<<"value">>, Attrs)),
    ?assertEqual({ok, <<"東京"/utf8>>}, xmlan:single_text(Tree)),
    Child = {<<"child">>, [], ["árvíz"]},
    Added = xmlan:add_new_element(Child, Tree),
    ?assertEqual([<<"東京"/utf8>>, Child], element(3, Added)),
    ?assertEqual({ok, <<"árvíz"/utf8>>}, xmlan:single_text(Child)),
    {Value, ExpandedName} = metadata(),
    {Added, {ExpandedName, [{<<"value">>, Value}], []}, #{<<"p">> => <<"urn:example">>}}.
