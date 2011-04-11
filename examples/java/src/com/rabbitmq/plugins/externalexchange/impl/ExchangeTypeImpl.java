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

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.MessageProperties;
import com.rabbitmq.client.QueueingConsumer;
import com.rabbitmq.client.ShutdownSignalException;
import com.rabbitmq.client.AMQP.BasicProperties;
import com.rabbitmq.client.AMQP.Queue;
import com.rabbitmq.client.QueueingConsumer.Delivery;
import com.rabbitmq.client.impl.LongStringHelper.ByteArrayLongString;
import com.rabbitmq.plugins.externalexchange.Binding;
import com.rabbitmq.plugins.externalexchange.ExchangeType;

public abstract class ExchangeTypeImpl implements Runnable, ExchangeType {

    private final QueueingConsumer consumer;
    private final Channel chan;

    public ExchangeTypeImpl(Connection conn) throws IOException {
        this(conn, "#");
    }

    public ExchangeTypeImpl(Connection conn, String bindingKey)
            throws IOException {
        chan = conn.createChannel();
        consumer = new QueueingConsumer(chan);
        Queue.DeclareOk queueDecl = chan.queueDeclare();
        String qName = queueDecl.getQueue();
        chan.queueBind(qName, "external-exchange", bindingKey);
        chan.txSelect();
        chan.basicQos(1);
        chan.basicConsume(qName, false, "", false, true, null, consumer);
    }

    private String getStringFromMap(String key, Map<String, Object> map) {
        return ((ByteArrayLongString) map.get(key)).toString();
    }

    private String [] getStringArrayFromMap(String key, Map<String, Object> map) {
        ArrayList<String> entries = new ArrayList<String>();
        for (Object entry : (List) map.get(key)){
            entries.add(((ByteArrayLongString) entry).toString());
        }
        return entries.toArray(new String []{});
    }

    @SuppressWarnings("unchecked")
    @Override
    public void run() {
        try {
            while (true) {
                Delivery delivery = consumer.nextDelivery();
                chan.basicAck(delivery.getEnvelope().getDeliveryTag(), false);
                Map<String, Object> headers = delivery.getProperties()
                        .getHeaders();
                String action = getStringFromMap("action", headers);
                String exchangeName = delivery.getEnvelope().getRoutingKey();

                if ("add_binding".equals(action)) {
                    Binding binding = new BindingImpl(getStringFromMap("key",
                            headers), getStringFromMap("queue_name", headers));
                    addBinding(exchangeName, binding);

                } else if ("remove_bindings".equals(action)) {
                    Map<String, Object>[] bindingMaps = (Map<String, Object>[]) headers
                            .get("bindings");
                    Binding[] bindings = new Binding[bindingMaps.length];
                    for (int idx = 0; idx < bindings.length; ++idx) {
                        Map<String, Object> map = bindingMaps[idx];
                        bindings[idx] = new BindingImpl(getStringFromMap("key",
                                map), getStringFromMap("queue_name", map));
                    }
                    removeBindings(exchangeName, bindings);

                } else if ("create".equals(action)) {
                    boolean durable = (Boolean) headers.get("durable");
                    boolean autoDelete = (Boolean) headers.get("auto_delete");
                    Map<String, Object> args = (Map<String, Object>) headers
                            .get("arguments");
                    create(exchangeName, durable, autoDelete, args);

                } else if ("delete".equals(action)) {
                    delete(exchangeName);

                } else if ("publish".equals(action)) {
                    Set<String> queueNames = publish(exchangeName, delivery
                            .getBody(),
                            getStringArrayFromMap("routing_keys", headers));
                    String replyQueue = delivery.getProperties().getReplyTo();
                    headers = new HashMap<String, Object>();
                    if (null != queueNames && 0 < queueNames.size()) {
                        headers.put("queue_names", new ArrayList(queueNames));
                    } else {
                        headers.put("queue_names", new ArrayList());
                    }
                    BasicProperties props = MessageProperties.MINIMAL_BASIC;
                    props.setHeaders(headers);
                    chan.basicPublish("", replyQueue, props, new byte[0]);

                } else {
                    throw new IllegalArgumentException(action);
                }
                chan.txCommit();
            }
        } catch (ShutdownSignalException e) {
            // don't care
        } catch (InterruptedException e) {
            // don't care
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                chan.close();
            } catch (IOException e) {
                // don't care
            }
        }
    }
}
