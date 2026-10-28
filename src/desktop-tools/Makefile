CC ?= cc
PREFIX ?= $(HOME)/.local
CFLAGS ?= -Os -Wall -Wextra
all: t480-screenshot t480-keys t480-touchpad

t480-screenshot: t480-screenshot.c
	$(CC) $(CFLAGS) $< -o $@ -lX11 -lXmu -lpng

t480-keys: t480-keys.c
	$(CC) $(CFLAGS) $< -o $@ -lX11 -lXtst

t480-touchpad: t480-touchpad.c
	$(CC) $(CFLAGS) $< -o $@ -lX11 -lXi

install: all
	install -d -m755 $(PREFIX)/bin
	install -m755 t480-screenshot t480-keys t480-touchpad $(PREFIX)/bin/

clean:
	rm -f t480-screenshot t480-keys t480-touchpad
.PHONY: all install clean
