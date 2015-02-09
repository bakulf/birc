VER_MAJOR = 0
VER_MINOR = 0
VER_PATCH = 1

CC = gcc
CFLAGS += -O2 -Wall -fPIC
CFLAGS += $(shell pkg-config gconf-2.0 glib-2.0 --cflags)
CFLAGS += -DPVERSION=\"$(VER_MAJOR).$(VER_MINOR).$(VER_PATCH)\"
LDFLAGS = -shared $(shell pkg-config gconf-2.0 glib-2.0 --libs)
LIBRARY = btermnotify-$(VER_MAJOR).$(VER_MINOR).$(VER_PATCH).so
OBJECTS = btermnotify.o

ALL : $(LIBRARY)

$(LIBRARY) : $(OBJECTS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(LIBRARY) $(OBJECTS)

btermnotify.o : btermnotify.c

.PHONY : clean
clean :
	rm -rf *.o *.so *~

.PHONY : install
install : $(LIBRARY)
	rm -f $(HOME)/.weechat/btermnotify-plugin.so
	cp ./$(LIBRARY) $(HOME)/.weechat/btermnotify-plugin.so

