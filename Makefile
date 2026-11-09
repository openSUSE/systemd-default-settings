NAME = systemd-default-settings

# Brandings are built by stacking layers on top of the base layer. Each layer is
# a set of drop-ins identified by their filename suffix
# (*-defaults-<layer>.conf). Layers are listed from the most generic to the most
# specific; the drop-in priority encoded in the filename must follow the same
# order.
#
# The base layer is implicitly part of all brandings and is shipped by the main
# package, the other layers are shipped by the branding sub-packages.
BASE_LAYER = SUSE

LAYERS_SLE       = SLE
LAYERS_SLE-Micro = SLE SLE-Micro
LAYERS_openSUSE  = openSUSE

BRANDINGS = SLE SLE-Micro openSUSE

# Don't rely on git so that it also works from the release tarball.
ALL_FILES := $(sort $(shell find usr -type f))

# $(call layer_files,<layer>...): drop-ins of the given layers, in layer order.
layer_files = $(foreach l,$(1),$(filter %-defaults-$(l).conf,$(ALL_FILES)))

# Print files as installed paths, one per line, suitable for '%files -f'. The
# drop-in directories containing the files are listed too (with '%dir') so they
# are owned by the package. They can be shared with other packages shipping
# drop-ins in the same directories, which is fine for RPM.
#
# Nothing is printed if the list is empty, otherwise printf would still output
# its format once and the package would end up owning '/'.
print_paths = $(if $(strip $(1)),\
	printf '%%dir /%s\n' $(patsubst %/,%,$(sort $(dir $(1)))) && \
	printf '/%s\n' $(1))

BASE_FILES := $(call layer_files,$(BASE_LAYER))

ifeq ($(BRANDING),)
# Install the drop-ins of all brandings. This is what the package build uses,
# as it produces all the branding sub-packages at once and then splits the files
# with 'list-base' and 'list-branding'.
FILES := $(ALL_FILES)
BRANDING_FILES :=
else ifneq ($(filter $(BRANDING),$(BRANDINGS)),)
BRANDING_FILES := $(call layer_files,$(LAYERS_$(BRANDING)))
FILES := $(BASE_FILES) $(BRANDING_FILES)
else
$(error Unknown BRANDING '$(BRANDING)', valid values are: $(BRANDINGS))
endif

.PHONY: all install list list-base list-branding archive clean

all:

install:
	@for f in $(FILES); do \
		echo "install $$f"; \
		install -D -m 0644 "$$f" "$(DESTDIR)/$$f" || exit 1; \
	done

# Show the drop-ins that would be installed for the selected branding (all
# brandings if BRANDING is unset).
list:
	@$(call print_paths,$(FILES))

# Show the drop-ins of the base layer only (main package).
list-base:
	@$(call print_paths,$(BASE_FILES))

# Show the drop-ins specific to BRANDING, i.e. without the base layer
# (branding sub-package).
list-branding:
ifeq ($(BRANDING),)
	$(error list-branding requires BRANDING, valid values are: $(BRANDINGS))
endif
	@$(call print_paths,$(BRANDING_FILES))

archive:
	@ver=$$(git describe --always) && \
	git archive --format=tgz --prefix=$(NAME)-$$ver/ HEAD >$(NAME)-$$ver.tar.gz

clean:
	rm -f *.tar.gz
