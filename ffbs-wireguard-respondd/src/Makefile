all: respondd.so

CFLAGS += -Wall -fPIC

respondd.so: respondd.c wireguard.o
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -shared -D_GNU_SOURCE -o $@ $^ $(LDLIBS)
