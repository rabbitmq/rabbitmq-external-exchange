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

-ifdef(use_specs).

-type(exchange_name(), string()).
-type(binding_key(), string()).
-type(routing_key(), string()).
-type(queue_name(), string()).
-type(binding(), {binding_key(), queue_name()}).
-type(payload(), binary()).
-type(state(), any()).

-spec(init/1 :: ([any()]) -> state()).
-spec(publish/4 :: (exchange_name(), [routing_key()], payload(), state()) ->
                        {[queue_name()], state()}).
-spec(create/5 :: (exchange_name(), boolean(), boolean(), amqp_table(), state())
                  -> state()).
-spec(delete/2 :: (exchange_name(), state()) -> state()).
-spec(add_binding/3 :: (exchange_name(), binding(), state()) -> state()).
-spec(remove_bindings/3 :: (exchange_name(), [binding()], state()) -> state()).
-spec(terminate/2 :: (any(), state()) -> any()).

-endif.
