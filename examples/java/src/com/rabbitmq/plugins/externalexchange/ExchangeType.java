/*   The contents of this file are subject to the Mozilla Public License
 **   Version 1.1 (the "License"); you may not use this file except in
 **   compliance with the License. You may obtain a copy of the License at
 **   http://www.mozilla.org/MPL/
 **
 **   Software distributed under the License is distributed on an "AS IS"
 **   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 **   License for the specific language governing rights and limitations
 **   under the License.
 **
 **   The Original Code is rabbitmq-external-exchange.
 **
 **   The Initial Developers of the Original Code are Rabbit Technologies Ltd.
 **
 **   All Rights Reserved.
 **
 **   Contributor(s): ______________________________________.
 */

package com.rabbitmq.plugins.externalexchange;

import java.util.Map;
import java.util.Set;

public interface ExchangeType {

    Set<String> publish(String exchangeName, byte[] body, String[] routingKeys);

    void create(String exchangeName, boolean durable, boolean autoDelete,
            Map<String, Object> arguments);

    void delete(String exchangeName);

    void addBinding(String exchangeName, Binding binding);

    void removeBindings(String exchangeName, Binding[] bindings);
}
