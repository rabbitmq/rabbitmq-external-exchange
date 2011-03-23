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

-module(rabbit_external_exchange_example).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("rabbit_external_exchange_type_spec.hrl").

-behaviour(rabbit_external_exchange_type).

-export([start/0, stop/0, start/2, stop/1]).
-export([init/1, publish/4, create/5, delete/2, add_binding/3,
         remove_bindings/3, terminate/2]).

%%----------------------------------------------------------------------------

start()           -> start_link(), ok.

stop()            -> ok.

start(normal, []) -> start_link().

stop(_State)      -> ok.

start_link() ->
    XName = <<"test-exchange">>,
    {ok, Conn} = amqp_connection:start(network),
    Res = rabbit_external_exchange_driver:start_link(Conn, XName, ?MODULE, []),

    {ok, Chan} = amqp_connection:open_channel(Conn),

    #'exchange.declare_ok'{} = amqp_channel:call(Chan, #'exchange.declare'{
                                                   exchange = XName,
                                                   type = <<"x-ee">> }),

    QName = <<"test-queue">>,
    #'queue.declare_ok'{} = amqp_channel:call(Chan, #'queue.declare'{
                                                queue = QName,
                                                exclusive = true,
                                                auto_delete = true }),
    #'queue.bind_ok'{} = amqp_channel:call(Chan, #'queue.bind'{
                                             queue = QName,
                                             exchange = XName,
                                             routing_key = <<"foo">> }),

    ok = amqp_channel:cast(
           Chan, #'basic.publish' { exchange = XName, routing_key = <<"bar">> },
           #amqp_msg { props = #'P_basic'{},
                       payload = <<"Hello Magic External Exchange">> }),

    #'basic.consume_ok'{} =
        amqp_channel:subscribe(Chan,
                               #'basic.consume'{ queue = QName,
                                                 exclusive = true },
                               self()),
    receive
        #'basic.consume_ok'{ consumer_tag = Tag } ->
            receive
                {#'basic.deliver'{ consumer_tag = Tag,
                                   delivery_tag = AckTag,
                                   routing_key  = RK },
                 #amqp_msg { payload = Payload }} ->
                    io:format("Msg:~s~nKey:~s~n",
                              [binary_to_list(Payload), RK]),
                    ok = amqp_channel:call(Chan, #'basic.ack'{
                                             delivery_tag = AckTag })
            end
    end,

    #'exchange.delete_ok'{} = amqp_channel:call(Chan, #'exchange.delete'{
                                                  exchange = XName }),
    amqp_channel:close(Chan),

    Res.

%%----------------------------------------------------------------------------

-record(state, { exchange_queues_map }).

init([]) ->
    #state { exchange_queues_map = dict:new() }.

publish(XName, _RK, _Payload, State = #state { exchange_queues_map = EQM }) ->
    {case dict:find(XName, EQM) of
         error    -> [];
         {ok, Qs} -> sets:to_list(Qs)
     end, State}.

create(_XName, _Durable, _AutoDelete, _Args, State) ->
    State.

delete(XName, State = #state { exchange_queues_map = EQM }) ->
    State #state { exchange_queues_map = dict:erase(XName, EQM) }.

add_binding(XName, {_BK, QName},
            State = #state { exchange_queues_map = EQM }) ->
    State #state { exchange_queues_map =
                       dict:update(
                         XName, fun (Set) -> sets:add_element(QName, Set) end,
                         sets:from_list([QName]), EQM) }.

remove_bindings(XName, Bindings,
                State = #state { exchange_queues_map = EQM }) ->
    Subtraction = sets:from_list([QName || {_BK, QName} <- Bindings]),
    EQM1 =
        case sets:find(XName, EQM) of
            error     -> EQM;
            {ok, Set} -> dict:store(XName, sets:subtract(Set, Subtraction), EQM)
        end,
    State #state { exchange_queues_map = EQM1 }.

terminate(_Reason, State) ->
    State.
