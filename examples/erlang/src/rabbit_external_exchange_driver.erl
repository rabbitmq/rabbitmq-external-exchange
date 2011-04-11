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

-module(rabbit_external_exchange_driver).

-include_lib("amqp_client/include/amqp_client.hrl").

-behaviour(gen_server).

-export([start_link/4]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%----------------------------------------------------------------------------

start_link(Connection, BindingKey, Module, ModArgs) ->
    gen_server:start_link(?MODULE, [Connection, BindingKey, Module, ModArgs],
                          [{timeout, infinity}]).

%%----------------------------------------------------------------------------

-record(state, {channel, ctag, module, mod_state}).

init([Conn, BindingKey, Module, ModArgs]) ->
    {ok, Chan} = amqp_connection:open_channel(Conn),
    #'queue.declare_ok'{ queue = Q } =
        amqp_channel:call(Chan, #'queue.declare'{ exclusive = true,
                                                  auto_delete = true }),
    #'queue.bind_ok'{} =
        amqp_channel:call(Chan,
                          #'queue.bind'{ queue = Q,
                                         exchange = <<"external-exchange">>,
                                         routing_key = BindingKey }),
    #'tx.select_ok'{} = amqp_channel:call(Chan, #'tx.select'{}),
    #'basic.qos_ok'{} =
        amqp_channel:call(Chan, #'basic.qos'{ prefetch_count = 1 }),
    #'basic.consume_ok'{} =
        amqp_channel:subscribe(Chan,
                               #'basic.consume'{ queue = Q, exclusive = true },
                               self()),
    CTag = receive
               #'basic.consume_ok'{ consumer_tag = Tag } -> Tag
           end,
    {ok, #state { channel = Chan, ctag = CTag, module = Module,
                  mod_state = Module:init(ModArgs) }}.

handle_call(Msg, _From, State) ->
    {stop, {unexpected_call, Msg}, State}.

handle_cast(Msg, State) ->
    {stop, {unexpected_cast, Msg}, State}.

handle_info({#'basic.deliver'{ consumer_tag = CTag, delivery_tag = AckTag,
                               routing_key = ExchangeName },
             #amqp_msg { props = #'P_basic' { headers = Headers,
                                              reply_to = ReplyTo },
                         payload = Payload }},
            State = #state { channel = Chan, ctag = CTag, module = Module,
                             mod_state = ModState }) ->
    ModState1 =
        case lists:keysearch(<<"action">>, 1, Headers) of
            {value, {<<"action">>, longstr, <<"publish">>}} ->
                {value, {<<"routing_keys">>, array, Routes}} =
                    lists:keysearch(<<"routing_keys">>, 1, Headers),
                {QNames, ModState2} =
                    Module:publish(ExchangeName, Routes, Payload, ModState),
                Headers1 = [{<<"queue_names">>, array,
                             [{longstr, QN} || QN <- QNames]}],
                Method = #'basic.publish' { routing_key = ReplyTo },
                Msg = #amqp_msg { props = #'P_basic'{ headers = Headers1 } },
                ok = amqp_channel:cast(Chan, Method, Msg),
                ModState2;

            {value, {<<"action">>, longstr, <<"create">>}} ->
                [Durable, AutoDelete, Args] =
                    [V || {F, Type} <- [{<<"durable">>,     bool},
                                        {<<"auto_delete">>, bool},
                                        {<<"arguments">>,   table}],
                          case lists:keysearch(F, 1, Headers) of
                              {value, {F, Type, Val}} -> V = Val, true;
                              _                       -> V = undefined, false
                          end],
                Module:create(ExchangeName, Durable, AutoDelete, Args,
                              ModState);

            {value, {<<"action">>, longstr, <<"delete">>}} ->
                Module:delete(ExchangeName, ModState);

            {value, {<<"action">>, longstr, <<"add_binding">>}} ->
                Module:add_binding(ExchangeName, extract_binding(Headers),
                                   ModState);

            {value, {<<"action">>, longstr, <<"remove_bindings">>}} ->
                {value, {<<"bindings">>, array, Bindings}} =
                    lists:keysearch(<<"bindings">>, 1, Headers),
                Module:remove_bindings(ExchangeName,
                                       [extract_binding(L) || L <- Bindings],
                                       ModState)
        end,
    ok = amqp_channel:cast(Chan, #'basic.ack'{ delivery_tag = AckTag }),
    #'tx.commit_ok'{} = amqp_channel:call(Chan, #'tx.commit'{}),
    {noreply, State #state { mod_state = ModState1 }};

handle_info(Msg, State) ->
    {stop, {unexpected_info, Msg}, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(Reason, State = #state { channel = Chan, module = Module,
                                    mod_state = ModState }) ->
    Module:terminate(Reason, ModState),
    amqp_channel:close(Chan),
    State.

extract_binding(List) ->
    {value, {<<"key">>, longstr, BindingKey}} =
        lists:keysearch(<<"key">>, 1, List),
    {value, {<<"queue_name">>, longstr, QName}} =
        lists:keysearch(<<"queue_name">>, 1, List),
    {BindingKey, QName}.
