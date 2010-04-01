{application, rabbit_external_exchange,
 [{description, "RabbitMQ external exchange plugin"},
  {vsn, "0.01"},
  {modules, [
    rabbit_external_exchange
  ]},
  {registered, []},
  {env, []},
  {mod, {rabbit_external_exchange, []}},
  {applications, [kernel, stdlib, rabbit]}]}.
