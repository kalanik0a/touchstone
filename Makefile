PREFIX ?= /usr/local
BINDIR  = $(PREFIX)/bin
LIBDIR  = $(PREFIX)/lib/touchstone

.PHONY: install uninstall check test

install:
	@echo "Installing Touchstone to $(PREFIX)..."
	@mkdir -p $(DESTDIR)$(BINDIR) $(DESTDIR)$(LIBDIR)
	@cp -R lib/. $(DESTDIR)$(LIBDIR)/
	@for tool in bin/ts-*; do \
		name=$$(basename $$tool); \
		sed 's|$$(cd "$$(dirname "$$0")/../lib" && pwd)|$(LIBDIR)|' $$tool > $(DESTDIR)$(BINDIR)/$$name; \
		chmod +x $(DESTDIR)$(BINDIR)/$$name; \
	done
	@echo "Installed: ts-sudo ts-ssh ts-scp ts-sftp ts-run"
	@echo "Run 'ts-sudo whoami' to verify."

uninstall:
	@echo "Removing Touchstone from $(PREFIX)..."
	@rm -f $(DESTDIR)$(BINDIR)/ts-sudo
	@rm -f $(DESTDIR)$(BINDIR)/ts-ssh
	@rm -f $(DESTDIR)$(BINDIR)/ts-scp
	@rm -f $(DESTDIR)$(BINDIR)/ts-sftp
	@rm -f $(DESTDIR)$(BINDIR)/ts-run
	@rm -rf $(DESTDIR)$(LIBDIR)
	@echo "Removed."

check:
	@echo "Checking dependencies..."
	@command -v wezterm >/dev/null && printf '  %-12s ✓\n' "wezterm" || printf '  %-12s ✗ (required)\n' "wezterm"
	@command -v sudo    >/dev/null && printf '  %-12s ✓\n' "sudo"    || printf '  %-12s ✗\n' "sudo"
	@command -v ssh     >/dev/null && printf '  %-12s ✓\n' "ssh"     || printf '  %-12s ✗\n' "ssh"
	@command -v less    >/dev/null && printf '  %-12s ✓\n' "less"    || printf '  %-12s ✗\n' "less"
	@command -v bash    >/dev/null && printf '  %-12s ✓\n' "bash"    || printf '  %-12s ✗\n' "bash"
	@test -d /etc/pam.d           && printf '  %-12s ✓\n' "PAM"     || printf '  %-12s ✗\n' "PAM"
	@echo ""
	@echo "Optional (for hardware-bound auth):"
	@dpkg -l libpam-u2f 2>/dev/null | grep -q ^ii && printf '  %-12s ✓\n' "pam_u2f" || \
		rpm -q pam-u2f 2>/dev/null | grep -q pam-u2f && printf '  %-12s ✓\n' "pam_u2f" || \
		test -f /etc/pam.d/sudo && grep -q u2f /etc/pam.d/sudo 2>/dev/null && printf '  %-12s ✓\n' "pam_u2f" || \
		printf '  %-12s ? (check: pam_u2f, libfido2)\n' "pam_u2f"

test:
	@python3 -m unittest discover -s tests -v
	@python3 -m py_compile hooks/touchstone_gate.py
	@for file in bin/ts-* lib/*.sh lib/backends/*.sh; do bash -n "$$file"; done
	@bash tests/test_signing_backend.sh
	@echo "Touchstone unit, hook-contract, Python, and Bash syntax tests passed."
