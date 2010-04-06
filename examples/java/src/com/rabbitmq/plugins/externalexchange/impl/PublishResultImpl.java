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

import java.util.Set;

import com.rabbitmq.plugins.externalexchange.PublishResult;

public class PublishResultImpl implements PublishResult {

	private byte[] body = null;
	private String routingKey = null;
	private Set<String> queueNames = null;

	public PublishResultImpl() {
	}

	@Override
	public byte[] getBody() {
		return body;
	}

	@Override
	public String getRoutingKey() {
		return routingKey;
	}

	@Override
	public void setBody(byte[] body) {
		this.body = body;
	}

	@Override
	public void setRoutingKey(String routingKey) {
		this.routingKey = routingKey;
	}

	@Override
	public Set<String> getQueueNames() {
		return queueNames;
	}

	@Override
	public void setQueueNames(Set<String> queueNames) {
		this.queueNames = queueNames;
	}

}
