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

-module(rabbit_external_exchange_type).

-export([behaviour_info/1]).

behaviour_info(callbacks) ->
    [
     {init, 1},

     {publish, 4},

     %% called after declaration when previously absent
     {create, 5},

     %% called after exchange deletion.
     {delete, 2},

     %% called after a binding has been added
     {add_binding, 3},

     %% called after bindings have been deleted.
     {remove_bindings, 3},

     {terminate, 2}

    ];
behaviour_info(_Other) ->
    undefined.
