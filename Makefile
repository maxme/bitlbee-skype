-include config.mak

VERSION = 0.9.0
DATE := $(shell date +%Y-%m-%d)
# latest stable
BITLBEE_VERSION = 3.0.1

ifeq ($(ASCIIDOC),yes)
MANPAGES = skyped.1
else
MANPAGES =
endif

ifeq ($(BITLBEE),yes)
LIBS = skype.$(SHARED_EXT)
else
LIBS =
endif

all: $(LIBS) $(MANPAGES)

skype.$(SHARED_EXT): skype.c config.mak
ifeq ($(BITLBEE),yes)
	$(CC) $(CFLAGS) $(SHARED_FLAGS) -o skype.$(SHARED_EXT) skype.c $(LDFLAGS)
endif

install: all
ifeq ($(ASCIIDOC),yes)
	$(INSTALL) -d $(DESTDIR)$(mandir)/man1
	$(INSTALL) -m644 $(MANPAGES) $(DESTDIR)$(mandir)/man1
endif
ifeq ($(BITLBEE),yes)
	$(INSTALL) -d $(DESTDIR)$(plugindir)
	$(INSTALL) skype.$(SHARED_EXT) $(DESTDIR)$(plugindir)
endif
ifeq ($(SKYPE4PY),yes)
	$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL) -d $(DESTDIR)$(sysconfdir)
	$(INSTALL) skyped.py $(DESTDIR)$(bindir)/skyped
	perl -p -i -e 's|/usr/local/etc/skyped|$(sysconfdir)|' $(DESTDIR)$(bindir)/skyped
	$(INSTALL) -m644 skyped.conf.dist $(DESTDIR)$(sysconfdir)/skyped.conf
	perl -p -i -e 's|\$${prefix}|$(prefix)|' $(DESTDIR)$(sysconfdir)/skyped.conf
	$(INSTALL) -m644 skyped.cnf $(DESTDIR)$(sysconfdir)
endif

client: client.c

autogen: configure.ac
	cp $(shell ls /usr/share/automake-*/install-sh | tail -n1) ./
	autoconf

clean:
	rm -f $(LIBS) $(MANPAGES)

distclean: clean
	rm -f config.log config.mak config.status

autoclean: distclean
	rm -rf aclocal.m4 autom4te.cache configure install-sh

# take this from the kernel
check:
	perl checkpatch.pl --no-tree --file skype.c

test: all
	$(MAKE) -C t/ all

dist:
	git archive --format=tar --prefix=bitlbee-skype-$(VERSION)/ HEAD | tar xf -
	mkdir -p bitlbee-skype-$(VERSION)
	git log --no-merges |git name-rev --tags --stdin > bitlbee-skype-$(VERSION)/Changelog
	make -C bitlbee-skype-$(VERSION) autogen
	tar czf bitlbee-skype-$(VERSION).tar.gz bitlbee-skype-$(VERSION)
	rm -rf bitlbee-skype-$(VERSION)

release:
	git tag $(VERSION)
	$(MAKE) dist
	gpg --comment "See http://vmiklos.hu/gpg/ for info" \
		-ba bitlbee-skype-$(VERSION).tar.gz

doc: HEADER.html Changelog AUTHORS

HEADER.html: README Makefile
	asciidoc -a toc -a numbered -a sectids -o HEADER.html -a icons -a data-uri --attribute iconsdir=./images/icons README
	sed -i 's|@VERSION@|$(VERSION)|g' HEADER.html
	sed -i 's|@BITLBEE_VERSION@|$(BITLBEE_VERSION)|g' HEADER.html

Changelog: .git/refs/heads/master
	git log --no-merges |git name-rev --tags --stdin >Changelog

AUTHORS: .git/refs/heads/master
	git shortlog -s -n |sed 's/.*\t//'> AUTHORS

%.1: %.txt asciidoc.conf
	a2x --asciidoc-opts="-f asciidoc.conf" \
		-a bs_version=$(VERSION) -a bs_date=$(DATE) -f manpage $<
