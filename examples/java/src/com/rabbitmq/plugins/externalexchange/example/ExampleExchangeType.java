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

package com.rabbitmq.plugins.externalexchange.example;

import java.io.IOException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;
import com.rabbitmq.client.QueueingConsumer;
import com.rabbitmq.client.ShutdownSignalException;
import com.rabbitmq.client.AMQP.BasicProperties;
import com.rabbitmq.client.QueueingConsumer.Delivery;
import com.rabbitmq.plugins.externalexchange.Binding;
import com.rabbitmq.plugins.externalexchange.ExchangeType;
import com.rabbitmq.plugins.externalexchange.impl.ExchangeTypeImpl;

public class ExampleExchangeType extends ExchangeTypeImpl implements
        ExchangeType {

    public ExampleExchangeType(Connection conn, String bindingKey)
            throws IOException {
        super(conn, bindingKey);
    }

    private final Map<String, Set<String>> queueNames = new HashMap<String, Set<String>>();

    @Override
    public void addBinding(String exchangeName, Binding binding) {
        if (queueNames.containsKey(exchangeName)) {
            queueNames.get(exchangeName).add(binding.getQueueName());
        } else {
            Set<String> set = new HashSet<String>();
            set.add(binding.getQueueName());
            queueNames.put(exchangeName, set);
        }
    }

    @Override
    public void create(String exchangeName, boolean durable,
            boolean autoDelete, Map<String, Object> arguments) {
    }

    @Override
    public void delete(String exchangeName) {
        queueNames.remove(exchangeName);
    }

    @Override
    public Set<String> publish(String exchangeName, byte[] body,
            String[] routingKey) {
        return queueNames.get(exchangeName);
    }

    @Override
    public void removeBindings(String exchangeName, Binding[] bindings) {
        Set<String> queues = queueNames.get(exchangeName);
        for (Binding binding : bindings) {
            queues.remove(binding.getQueueName());
        }
    }

    public static void main(String[] args) throws IOException,
            ShutdownSignalException, InterruptedException {
        Connection conn = new ConnectionFactory().newConnection();
        String eName = "test-exchange";

        ExampleExchangeType eet = new ExampleExchangeType(conn, eName);
        new Thread(eet).start();

        Channel chan = conn.createChannel();
        chan.exchangeDeclare(eName, "x-ee");

        String qName = "test-queue";
        chan.queueDeclare(qName, false, true, false, null);
        chan.queueBind(qName, eName, "foo");

        chan.basicPublish(eName, "bar", new BasicProperties(),
                "Hello Magic External Exchange".getBytes("UTF-8"));

        QueueingConsumer consumer = new QueueingConsumer(chan);
        chan.basicConsume(qName, false, "", false, true, null, consumer);

        Delivery delivery = consumer.nextDelivery();

        System.out.println(new String(delivery.getBody(), "UTF-8") + " "
                + delivery.getEnvelope().getRoutingKey());

        chan.basicAck(delivery.getEnvelope().getDeliveryTag(), false);

        chan.exchangeDelete(eName);
        chan.close();
    }

}
