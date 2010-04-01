PACKAGE:=rabbit_external_exchange_example
DEPS:=rabbitmq-server rabbitmq-erlang-client
ROOT_DIR:=../../..
DEPS_FILE:=deps.mk

include ../../../include.mk

$(DEPS_FILE): $(SOURCES) $(INCLUDES)
	escript generate_deps $(INCLUDE_DIR) $(SOURCE_DIR) \$$\(EBIN_DIR\) $@

clean::
	rm -f $(DEPS_FILE)

-include $(DEPS_FILE)
