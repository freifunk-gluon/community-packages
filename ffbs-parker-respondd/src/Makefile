all: respondd.so

CFLAGS += -Wall -fPIC

respondd.so: respondd.c clients.c clients.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -shared -D_GNU_SOURCE -o $@ respondd.c clients.c $(LDLIBS) -liwinfo -luci
