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

package com.rabbitmq.plugins.externalexchange.impl;

import com.rabbitmq.plugins.externalexchange.Binding;

public class BindingImpl implements Binding {

    private final String bindingKey;
    private final String queueName;

    public BindingImpl(String bindingKey, String queueName) {
        this.bindingKey = bindingKey;
        this.queueName = queueName;
    }

    @Override
    public String getBindingKey() {
        return bindingKey;
    }

    @Override
    public String getQueueName() {
        return queueName;
    }

}
