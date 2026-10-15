-module(xmlan).

% Extracted from Signerl under Apache-2.0; see NOTICE.
-export([add_new_element/2, single_text/1, attr_value/2, attr_value_or_undefined/2]).

% Public, transparent tree: callers construct and pattern-match these tuples.
% Names and binary values are UTF-8; lists contain Unicode code points.
-type attribute_value() :: string() | binary() | integer() | atom().
-type simplified_xml_item() :: simplified_xml() | string() | binary().
-type simplified_xml() :: {binary(), [{binary(), attribute_value()}], [simplified_xml_item()]}.
-type expanded_name() :: {binary() | undefined, binary()}.
-type namespace_context() :: #{binary() => binary()}.
-type expanded_xml() ::
    {expanded_name(), [{binary(), attribute_value()}], [expanded_xml() | string() | binary()]}.
-export_type([
    simplified_xml/0,
    attribute_value/0,
    expanded_xml/0,
    expanded_name/0,
    namespace_context/0
]).

-spec add_new_element(NewElement, Xml) -> Xml when
    NewElement :: simplified_xml(),
    Xml :: simplified_xml().
add_new_element(NewElement, {Tag, Attrs, Content}) ->
    {Tag, Attrs, Content ++ [NewElement]}.

-spec single_text(Xml) -> Result when
    Xml :: simplified_xml(),
    Result :: {ok, binary()} | {error, not_found}.
single_text({_, _, [Text]}) when is_binary(Text) ->
    {ok, Text};
single_text({_, _, [Text]}) when is_list(Text) ->
    {ok, unicode:characters_to_binary(Text)};
single_text(_) ->
    {error, not_found}.

-spec attr_value(Key, Attrs) -> Result when
    Key :: binary(),
    Attrs :: [{binary(), attribute_value()}],
    Result :: {ok, attribute_value()} | {error, missing_attribute}.
attr_value(Key, Attrs) ->
    case lists:keyfind(Key, 1, Attrs) of
        {Key, Value} ->
            {ok, Value};
        false ->
            {error, missing_attribute}
    end.

-spec attr_value_or_undefined(Key, Attrs) -> Result when
    Key :: binary(),
    Attrs :: [{binary(), attribute_value()}],
    Result :: attribute_value() | undefined.
attr_value_or_undefined(Key, Attrs) ->
    case lists:keyfind(Key, 1, Attrs) of
        {Key, Value} ->
            Value;
        false ->
            undefined
    end.
