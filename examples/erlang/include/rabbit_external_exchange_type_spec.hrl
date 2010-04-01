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
%%   The Initial Developers of the Original Code are LShift Ltd,
%%   Cohesive Financial Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created before 22-Nov-2008 00:00:00 GMT by LShift Ltd,
%%   Cohesive Financial Technologies LLC, or Rabbit Technologies Ltd
%%   are Copyright (C) 2007-2008 LShift Ltd, Cohesive Financial
%%   Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created by LShift Ltd are Copyright (C) 2007-2010 LShift
%%   Ltd. Portions created by Cohesive Financial Technologies LLC are
%%   Copyright (C) 2007-2010 Cohesive Financial Technologies
%%   LLC. Portions created by Rabbit Technologies Ltd are Copyright
%%   (C) 2007-2010 Rabbit Technologies Ltd.
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
-spec(publish/4 :: (exchange_name(), routing_key(), payload(), state()) ->
                        {routing_key(), payload(), [queue_name()], state()}).
-spec(create/5 :: (exchange_name(), boolean(), boolean(), amqp_table(), state())
                  -> state()).
-spec(delete/2 :: (exchange_name(), state()) -> state()).
-spec(add_binding/3 :: (exchange_name(), binding(), state()) -> state()).
-spec(remove_bindings/3 :: (exchange_name(), [binding()], state()) -> state()).
-spec(terminate/2 :: (any(), state()) -> any()).

-endif.
