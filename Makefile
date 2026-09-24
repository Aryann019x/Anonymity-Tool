PREFIX ?= /usr/local
BIN = $(PREFIX)/bin/anonyx
LIBDIR = $(PREFIX)/share/anonyx/lib

install:
	install -Dm755 bin/anonyx $(DESTDIR)$(BIN)
	install -Dm644 lib/common.sh $(DESTDIR)$(LIBDIR)/common.sh
	install -Dm644 lib/audit.sh $(DESTDIR)$(LIBDIR)/audit.sh
	install -Dm644 lib/preflight.sh $(DESTDIR)$(LIBDIR)/preflight.sh
	install -Dm644 lib/nft.sh $(DESTDIR)$(LIBDIR)/nft.sh
	install -Dm644 lib/iptables_compat.sh $(DESTDIR)$(LIBDIR)/iptables_compat.sh
	install -Dm644 lib/netns.sh $(DESTDIR)$(LIBDIR)/netns.sh
	install -Dm644 lib/verify.sh $(DESTDIR)$(LIBDIR)/verify.sh
	install -Dm644 lib/mac.sh $(DESTDIR)$(LIBDIR)/mac.sh
	install -Dm644 lib/bridges.sh $(DESTDIR)$(LIBDIR)/bridges.sh
	install -Dm644 lib/watchdog.sh $(DESTDIR)$(LIBDIR)/watchdog.sh
	install -Dm644 etc/tor-killswitch/config.example $(DESTDIR)/etc/tor-killswitch/config.example
	install -Dm644 man/anonyx.1 $(DESTDIR)/usr/share/man/man1/anonyx.1
	install -Dm644 completions/anonyx.bash $(DESTDIR)/usr/share/bash-completion/completions/anonyx

check:
	bash -n bin/anonyx
	shellcheck -S warning bin/anonyx lib/*.sh

test:
	bats test/unit/
