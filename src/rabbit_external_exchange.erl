%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is rabbitmq-external-exchange.
%%
%%   The Initial Developers of the Original Code are Rabbit Technologies Ltd.
%%
%%   All Rights Reserved.
%%
%%   Contributor(s): ______________________________________.
%%

-module(rabbit_external_exchange).

-rabbit_boot_step({?MODULE,
                   [{description, "external exchange type"},
                    {mfa, {rabbit_registry, register,
                           [exchange, <<"x-ee">>, rabbit_external_exchange]}},
                    {requires, rabbit_registry},
                    {enables, exchange_recovery}]}).

-include_lib("rabbit_common/include/rabbit_exchange_type_spec.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-behaviour(rabbit_exchange_type).
-behaviour(gen_server).

-export([description/0, route/2, serialise_events/1]).
-export([validate/1, create/2, delete/3, add_binding/3,
         remove_bindings/3, assert_args_equivalence/2]).

-export([start/0, stop/0, start/2, stop/1]).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(EXCHANGE, <<"external-exchange">>).
-define(SERVER, ?MODULE).
-define(KEY, ?MODULE).
-define(TX, none).

%%----------------------------------------------------------------------------

description() ->
    [{name, <<"ee">>},
     {description, <<"External exchange.">>}].

serialise_events(_X) -> false.

route(#exchange{ name = XName },
        #delivery{
          message = #basic_message {
            routing_keys = Routes,
            content = #content { payload_fragments_rev = FragmentsRev } }}) ->
    RouteArg = [{longstr, Route} || Route <- Routes],
    ok = inform("publish", XName, [{<<"routing_keys">>, array, RouteArg}],
                iolist_to_binary(lists:reverse(FragmentsRev))),
    {Chan, _Q, CTag} = get_channel_and_queue(),
    receive
        {#'basic.deliver'{ consumer_tag = CTag, delivery_tag = AckTag },
         #amqp_msg { props = #'P_basic' { headers = Headers } }} ->
            ok = amqp_channel:call(Chan, #'basic.ack'{ delivery_tag = AckTag }),
            case lists:keysearch(<<"queue_names">>, 1, Headers) of
                false ->
                    [];
                {value, {<<"queue_names">>, array, QNames}} ->
                    [rabbit_misc:r(XName, queue, QName) ||
                        {longstr, QName} <- QNames]
            end
    end.

validate(_X) -> ok.

create(?TX,
       #exchange { name = XName, durable = Durable, auto_delete = AutoDelete,
                   arguments = Args }) ->
    ok = inform("create", XName, [{<<"durable">>,     bool,  Durable},
                                  {<<"auto_delete">>, bool,  AutoDelete},
                                  {<<"arguments">>,   table, Args}]);
create(_Tx, _X) ->
    ok.

delete(?TX, #exchange { name = XName }, Bindings) ->
    ok = inform("delete", XName, encode_bindings(Bindings));
delete(_Tx, _X, _Bs) ->
    ok.

add_binding(?TX, #exchange { name = XName }, Binding) ->
    ok = inform("add_binding", XName, encode_binding(Binding));
add_binding(_Tx, _X, _B) ->
    ok.

remove_bindings(?TX, #exchange { name = XName }, Bindings) ->
    ok = inform("remove_bindings", XName, encode_bindings(Bindings));
remove_bindings(_Tx, _X, _Bs) ->
    ok.

assert_args_equivalence(X, Args) ->
    rabbit_exchange:assert_args_equivalence(X, Args).

%%----------------------------------------------------------------------------

inform(ActionName, ExchangeName, Headers) ->
    inform(ActionName, ExchangeName, Headers, <<>>).

inform(ActionName, #resource { name = ExchangeName }, Headers, Payload) ->
    {Chan, Q, _CTag} = get_channel_and_queue(),
    Method = #'basic.publish' { exchange = ?EXCHANGE,
                                routing_key = ExchangeName },
    Props = #'P_basic'{ reply_to = Q,
                        headers = [{<<"action">>, longstr,
                                    list_to_binary(ActionName)} | Headers]},
    Msg = #amqp_msg { props = Props, payload = Payload },
    ok = amqp_channel:call(Chan, Method, Msg).

encode_bindings(Bindings) ->
    [{<<"bindings">>, array, [{table, encode_binding(B)} || B <- Bindings]}].

encode_binding(#binding { destination = #resource { name = QName },
                          key = Key }) ->
    [{<<"queue_name">>, longstr, QName}, {<<"key">>, longstr, Key}].

%%----------------------------------------------------------------------------

start()           -> start_link(), ok.

stop()            -> ok.

start(normal, []) -> start_link().

stop(_State)      -> ok.

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [],
                          [{timeout, infinity}]).

%%----------------------------------------------------------------------------

get_channel_and_queue() ->
    case get(?KEY) of
        undefined ->
            Me = self(),
            Chan = gen_server:call(?SERVER, {new_channel, Me}, infinity),
            #'basic.qos_ok'{} =
                amqp_channel:call(Chan, #'basic.qos'{ prefetch_count = 1 }),
            #'queue.declare_ok'{ queue = Q } =
                amqp_channel:call(Chan, #'queue.declare'{ exclusive = true,
                                                          auto_delete = true }),
            #'basic.consume_ok'{ consumer_tag = Tag } =
                amqp_channel:subscribe(
                  Chan, #'basic.consume'{ queue = Q, exclusive = true }, Me),
            receive
                #'basic.consume_ok'{ consumer_tag = Tag } -> ok
            end,
            undefined = put(?KEY, {Chan, Q, Tag}),
            {Chan, Q, Tag};
        {Chan, Q, Tag} ->
            {Chan, Q, Tag}
    end.

%%----------------------------------------------------------------------------

-record(state, { connection, channels }).

init([]) ->
    {ok, Conn} = amqp_connection:start(direct),
    {ok, Chan} = amqp_connection:open_channel(Conn),
    #'exchange.declare_ok'{} =
        amqp_channel:call(Chan, #'exchange.declare'{
                            exchange = ?EXCHANGE, type = <<"topic">> }),
    ok = amqp_channel:close(Chan),
    {ok, #state { connection = Conn, channels = dict:new() }}.

handle_call({new_channel, Pid}, _From, State = #state { connection = Conn,
                                                        channels = Chans }) ->
    {ok, Chan} = amqp_connection:open_channel(Conn),
    _MRef = erlang:monitor(process, Pid),
    {reply, Chan, State #state { channels = dict:append(Pid, Chan, Chans) }};

handle_call(Msg, _From, State) ->
    {stop, {unexpected_call, Msg}, State}.

handle_cast(Msg, State) ->
    {stop, {unexpected_cast, Msg}, State}.

handle_info({'DOWN', _MRef, process, Pid, _Info},
            State = #state { channels = Chans }) ->
    ok = case dict:find(Pid, Chans) of
             error          -> ok;
             {ok, Channels} -> [amqp_channel:close(C) || C <- Channels],
                               ok
         end,
    {noreply, State #state { channels = dict:erase(Pid, Chans) }};

handle_info(Msg, State) ->
    {stop, {unexpected_info, Msg}, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(_Reason, State = #state { connection = Conn }) ->
    amqp_connection:close(Conn),
    State.
