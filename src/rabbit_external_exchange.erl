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
                    {mfa, {rabbit_exchange_type_registry, register, [<<"x-ee">>, rabbit_external_exchange]}},
                    {requires, rabbit_exchange_type_registry},
                    {enables, exchange_recovery}]}).

-include_lib("rabbit_common/include/rabbit_exchange_type_spec.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-behaviour(rabbit_exchange_type).
-behaviour(gen_server).

-export([description/0, publish/2]).
-export([validate/1, recover/2, create/1, delete/2, add_binding/2,
         remove_bindings/2, assert_args_equivalence/2]).

-export([start/0, stop/0, start/2, stop/1]).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(EXCHANGE, <<"external-exchange">>).
-define(SERVER, ?MODULE).
-define(KEY, ?MODULE).

%%----------------------------------------------------------------------------

description() ->
    {{name, <<"ee">>},
     {description, <<"External exchange.">>}}.

publish(#exchange{ name = XName = #resource{ virtual_host = VHost }},
        Delivery = #delivery{
          message = Message =
              #basic_message {
                      routing_key = Key,
                      content = Content =
                          #content { payload_fragments_rev = FragmentsRev }
                     }}) ->
    ok = inform("publish", XName, [{<<"routing_key">>, longstr, Key}],
                iolist_to_binary(lists:reverse(FragmentsRev))),
    {Chan, _Q, CTag} = get_channel_and_queue(),
    receive
        {#'basic.deliver'{ consumer_tag = CTag, delivery_tag = AckTag },
         #amqp_msg { props = #'P_basic' { headers = Headers },
                     payload = Payload }} ->
            ok = amqp_channel:call(Chan, #'basic.ack'{ delivery_tag = AckTag }),
            Message1 = Message #basic_message {
                         content = Content #content {
                                     payload_fragments_rev = [Payload] }},
            Message2 = case lists:keysearch(<<"routing_key">>, 1, Headers) of
                           false ->
                               Message1;
                           {value, {<<"routing_key">>, longstr, Key1}} ->
                               Message1 #basic_message { routing_key = Key1 }
                       end,
            QPids = case lists:keysearch(<<"queue_names">>, 1, Headers) of
                        false ->
                            [];
                        {value, {<<"queue_names">>, array, QNames1}} ->
                            [QPid ||
                                {longstr, QName} <- QNames1,
                                case rabbit_amqqueue:lookup(rabbit_misc:r(VHost, queue, QName)) of
                                    {ok, Q} -> QPid = Q#amqqueue.pid, true;
                                    {error, not_found} -> QPid = none, false
                                end]
                    end,
            rabbit_router:deliver(QPids,
                                  Delivery #delivery { message = Message2 })
    end.

validate(_X) -> ok.

recover(X, Bindings) ->
    ok = create(X),
    [add_binding(X, B) || B <- Bindings],
    ok.

create(#exchange { name = XName, durable = Durable, auto_delete = AutoDelete,
                   arguments = Args }) ->
    ok = inform("create", XName, [{<<"durable">>,     bool,  Durable},
                                  {<<"auto_delete">>, bool,  AutoDelete},
                                  {<<"arguments">>,   table, Args}]).

delete(#exchange { name = XName }, Bindings) ->
    ok = inform("delete", XName, encode_bindings(Bindings)).

add_binding(#exchange { name = XName }, Binding) ->
    ok = inform("add_binding", XName, encode_binding(Binding)).

remove_bindings(#exchange { name = XName }, Bindings) ->
    ok = inform("remove_bindings", XName, encode_bindings(Bindings)).

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

encode_binding(#binding { queue_name = #resource { name = QName },
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
    Conn = amqp_connection:start_direct_link(),
    Chan = amqp_connection:open_channel(Conn),
    #'exchange.declare_ok'{} =
        amqp_channel:call(Chan, #'exchange.declare'{
                            exchange = ?EXCHANGE, type = <<"topic">> }),
    ok = amqp_channel:close(Chan),
    {ok, #state { connection = Conn, channels = dict:new() }}.

handle_call({new_channel, Pid}, _From, State = #state { connection = Conn,
                                                        channels = Chans }) ->
    Chan = amqp_connection:open_channel(Conn),
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
