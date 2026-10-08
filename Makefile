LIBDIR := lib

# Build with the locally installed kramdown-rfc (gem) and uv-installed xml2rfc,
# both on PATH. Empty REQUIREMENTS_TXT makes lib/deps.mk skip venv.mk, so the
# template never builds its own python3 -m venv (we use uv for Python).
# MUST stay above the include below: `make update` (update-makefile) preserves
# every line above `-include .../main.mk` and refreshes only the block below.
override REQUIREMENTS_TXT :=

-include $(LIBDIR)/main.mk

$(LIBDIR)/main.mk:
ifneq (,$(shell grep "path *= *$(LIBDIR)" .gitmodules 2>/dev/null))
	git submodule sync
	git submodule update --init
else
ifneq (,$(wildcard $(ID_TEMPLATE_HOME)))
	ln -s "$(ID_TEMPLATE_HOME)" $(LIBDIR)
else
	git clone -q --depth 10 -b main \
	    https://github.com/martinthomson/i-d-template $(LIBDIR)
endif
endif
