#
# Useful targets:
# - all             - build everything
# - macOS           - build everything for macOS
# - iOS             - build everything for iOS
# - tvOS            - build everything for tvOS
# - watchOS         - build everything for watchOS
# - BZip2           - build BZip2 for all platforms
# - BZip2-macOS     - build BZip2 for macOS
# - BZip2-iOS       - build BZip2 for iOS
# - BZip2-tvOS      - build BZip2 for tvOS
# - BZip2-watchOS   - build BZip2 for watchOS
# - XZ              - build XZ for all platforms
# - XZ-macOS        - build XZ for macOS
# - XZ-iOS          - build XZ for iOS
# - XZ-tvOS         - build XZ for tvOS
# - XZ-watchOS      - build XZ for watchOS
# - OpenSSL         - build OpenSSL for all platforms
# - OpenSSL-macOS   - build OpenSSL for macOS
# - OpenSSL-iOS     - build OpenSSL for iOS
# - OpenSSL-tvOS    - build OpenSSL for tvOS
# - OpenSSL-watchOS - build OpenSSL for watchOS
# - libFFI          - build libFFI for all platforms (except macOS)
# - libFFI-iOS      - build libFFI for iOS
# - libFFI-tvOS     - build libFFI for tvOS
# - libFFI-watchOS  - build libFFI for watchOS
# - Python          - build Python for all platforms
# - Python-macOS    - build Python for macOS
# - Python-iOS      - build Python for iOS
# - Python-tvOS     - build Python for tvOS
# - Python-watchOS  - build Python for watchOS

# Current directory
PROJECT_DIR=$(shell pwd)

# Supported OS and products
PRODUCTS=BZip2 XZ OpenSSL libFFI
OS_LIST=iOS tvOS watchOS

# The versions to compile by default.
# In practice, these should be
# This can be overwritten at build time:
# e.g., `make iOS BZIP2_VERSION=1.2.3`

BUILD_NUMBER=custom

BZIP2_VERSION=1.0.8

XZ_VERSION=5.4.4

# Preference is to use OpenSSL 3; however, Cryptography 3.4.8 (and
# probably some other packages as well) only works with 1.1.1, so
# we need to preserve the ability to build the older OpenSSL (for now...)
OPENSSL_VERSION=3.1.2
# OPENSSL_VERSION_NUMBER=1.1.1
# OPENSSL_REVISION=v
# OPENSSL_VERSION=$(OPENSSL_VERSION_NUMBER)$(OPENSSL_REVISION)


CURL_FLAGS=--disable --fail --location --create-dirs --progress-bar

# iOS targets
TARGETS-iOS=iphonesimulator.x86_64 iphonesimulator.arm64 iphoneos.arm64
VERSION_MIN-iOS=12.0
CFLAGS-iOS=-mios-version-min=$(VERSION_MIN-iOS)

# tvOS targets
TARGETS-tvOS=appletvsimulator.x86_64 appletvsimulator.arm64 appletvos.arm64
VERSION_MIN-tvOS=9.0
CFLAGS-tvOS=-mtvos-version-min=$(VERSION_MIN-tvOS)
PYTHON_CONFIGURE-tvOS=ac_cv_func_sigaltstack=no

# watchOS targets
TARGETS-watchOS=watchsimulator.x86_64 watchsimulator.arm64 watchos.arm64_32
VERSION_MIN-watchOS=4.0
CFLAGS-watchOS=-mwatchos-version-min=$(VERSION_MIN-watchOS)
PYTHON_CONFIGURE-watchOS=ac_cv_func_sigaltstack=no

# The architecture of the machine doing the build
HOST_ARCH=$(shell uname -m)

# Force the path to be minimal. This ensures that anything in the user environment
# (in particular, homebrew and user-provided Python installs) aren't inadvertently
# linked into the support package.
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin

# Build for all operating systems
all: $(OS_LIST)

.PHONY: \
	all clean distclean vars \
	$(foreach os,$(OS_LIST),$(os) clean-$(os) vars-$(os)) \
	$(foreach os,$(OS_LIST),$(foreach product,$(PRODUCTS),$(product)-$(os) clean-$(product)-$(os))) \
	$(foreach os,$(OS_LIST),$(foreach target,$$(TARGETS-$(os)),$(product)-$(target) clean-$(product)-$(target))) \
	$(foreach os,$(OS_LIST),$(foreach sdk,$$(sort $$(basename $$(TARGETS-$(os)))),$(product)-$(sdk) clean-$(product)-$(sdk)))

# Clean all builds
clean:
	rm -rf build install dist

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

###########################################################################
# Setup: BZip2
###########################################################################

# Download original BZip2 source code archive.
downloads/bzip2-$(BZIP2_VERSION).tar.gz:
	@echo ">>> Download BZip2 sources"
	curl $(CURL_FLAGS) -o $@ \
		https://sourceware.org/pub/bzip2/$(notdir $@)

###########################################################################
# Setup: XZ (LZMA)
###########################################################################

# Download original XZ source code archive.
downloads/xz-$(XZ_VERSION).tar.gz:
	@echo ">>> Download XZ sources"
	curl $(CURL_FLAGS) -o $@ \
		https://tukaani.org/xz/$(notdir $@)

###########################################################################
# Setup: OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tar.gz:
	@echo ">>> Download OpenSSL sources"
	curl $(CURL_FLAGS) -o $@ \
		https://openssl.org/source/$(notdir $@) \
		|| curl $(CURL_FLAGS) -o $@ \
			https://openssl.org/source/old/$(basename $(OPENSSL_VERSION))/$(notdir $@)

###########################################################################
# Setup: libFFI
###########################################################################

# Download original libFFI source code archive.
downloads/libffi-$(LIBFFI_VERSION).tar.gz:
	@echo ">>> Download libFFI sources"
	curl $(CURL_FLAGS) -o $@ \
		https://github.com/libffi/libffi/releases/download/v$(LIBFFI_VERSION)/$(notdir $@)

###########################################################################
# Build for specified target (from $(TARGETS-*))
###########################################################################
#
# Parameters:
# - $1 - target (e.g., iphonesimulator.x86_64, iphoneos.arm64)
# - $2 - OS (e.g., iOS, tvOS)
#
###########################################################################
define build-target
target=$1
os=$2

OS_LOWER-$(target)=$(shell echo $(os) | tr '[:upper:]' '[:lower:]')

# $(target) can be broken up into is composed of $(SDK).$(ARCH)
SDK-$(target)=$$(basename $(target))
ARCH-$(target)=$$(subst .,,$$(suffix $(target)))

ifeq ($$(findstring simulator,$$(SDK-$(target))),)
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))$$(VERSION_MIN-$(os))
else
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))$$(VERSION_MIN-$(os))-simulator
endif

SDK_ROOT-$(target)=$$(shell xcrun --sdk $$(SDK-$(target)) --show-sdk-path)
CC-$(target)=xcrun --sdk $$(SDK-$(target)) clang -target $$(TARGET_TRIPLE-$(target))
CFLAGS-$(target)=\
	--sysroot=$$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os))
LDFLAGS-$(target)=\
	-isysroot $$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os))

###########################################################################
# Target: BZip2
###########################################################################

BZIP2_SRCDIR-$(target)=build/$(os)/$(target)/bzip2-$(BZIP2_VERSION)
BZIP2_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/bzip2-$(BZIP2_VERSION)
BZIP2_LIB-$(target)=$$(BZIP2_INSTALL-$(target))/lib/libbz2.a
BZIP2_DIST-$(target)=dist/bzip2-$(BZIP2_VERSION)-$(BUILD_NUMBER)-$(target).tar.gz

$$(BZIP2_SRCDIR-$(target))/Makefile: downloads/bzip2-$(BZIP2_VERSION).tar.gz
	@echo ">>> Unpack BZip2 sources for $(target)"
	mkdir -p $$(BZIP2_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(BZIP2_SRCDIR-$(target))
	# Touch the makefile to ensure that Make identifies it as up to date.
	touch $$(BZIP2_SRCDIR-$(target))/Makefile

$$(BZIP2_LIB-$(target)): $$(BZIP2_SRCDIR-$(target))/Makefile
	@echo ">>> Build BZip2 for $(target)"
	cd $$(BZIP2_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		make install \
			PREFIX="$$(BZIP2_INSTALL-$(target))" \
			CC="$$(CC-$(target))" \
			CFLAGS="$$(CFLAGS-$(target))" \
			LDFLAGS="$$(LDFLAGS-$(target))" \
			2>&1 | tee -a ../bzip2-$(BZIP2_VERSION).build.log

$$(BZIP2_DIST-$(target)): $$(BZIP2_LIB-$(target))
	@echo ">>> Build BZip2 distribution for $(target)"
	mkdir -p dist

	cd $$(BZIP2_INSTALL-$(target)) && tar zcvf $(PROJECT_DIR)/$$(BZIP2_DIST-$(target)) lib include

BZip2-$(target): $$(BZIP2_DIST-$(target))

###########################################################################
# Target: XZ (LZMA)
###########################################################################

XZ_SRCDIR-$(target)=build/$(os)/$(target)/xz-$(XZ_VERSION)
XZ_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/xz-$(XZ_VERSION)
XZ_LIB-$(target)=$$(XZ_INSTALL-$(target))/lib/liblzma.a
XZ_DIST-$(target)=dist/xz-$(XZ_VERSION)-$(BUILD_NUMBER)-$(target).tar.gz

$$(XZ_SRCDIR-$(target))/configure: downloads/xz-$(XZ_VERSION).tar.gz
	@echo ">>> Unpack XZ sources for $(target)"
	mkdir -p $$(XZ_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(XZ_SRCDIR-$(target))
	# Patch the source to add support for new platforms
	cd $$(XZ_SRCDIR-$(target)) && patch -p1 < $(PROJECT_DIR)/patch/xz-$(XZ_VERSION).patch
	# Touch the configure script to ensure that Make identifies it as up to date.
	touch $$(XZ_SRCDIR-$(target))/configure

$$(XZ_SRCDIR-$(target))/Makefile: $$(XZ_SRCDIR-$(target))/configure
	# Configure the build
	cd $$(XZ_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		./configure \
			CC="$$(CC-$(target))" \
			CFLAGS="$$(CFLAGS-$(target))" \
			LDFLAGS="$$(LDFLAGS-$(target))" \
			--disable-shared \
			--enable-static \
			--host=$$(TARGET_TRIPLE-$(target)) \
			--build=$(HOST_ARCH)-apple-darwin \
			--prefix="$$(XZ_INSTALL-$(target))" \
			2>&1 | tee -a ../xz-$(XZ_VERSION).config.log

$$(XZ_LIB-$(target)): $$(XZ_SRCDIR-$(target))/Makefile
	@echo ">>> Build and install XZ for $(target)"
	cd $$(XZ_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		make install \
			2>&1 | tee -a ../xz-$(XZ_VERSION).build.log

$$(XZ_DIST-$(target)): $$(XZ_LIB-$(target))
	@echo ">>> Build XZ distribution for $(target)"
	mkdir -p dist

	cd $$(XZ_INSTALL-$(target)) && tar zcvf $(PROJECT_DIR)/$$(XZ_DIST-$(target)) lib include

XZ-$(target): $$(XZ_DIST-$(target))

###########################################################################
# Target: Debug
###########################################################################

vars-$(target):
	@echo ">>> Environment variables for $(target)"
	@echo "SDK-$(target): $$(SDK-$(target))"
	@echo "ARCH-$(target): $$(ARCH-$(target))"
	@echo "TARGET_TRIPLE-$(target): $$(TARGET_TRIPLE-$(target))"
	@echo "SDK_ROOT-$(target): $$(SDK_ROOT-$(target))"
	@echo "CC-$(target): $$(CC-$(target))"
	@echo "CFLAGS-$(target): $$(CFLAGS-$(target))"
	@echo "LDFLAGS-$(target): $$(LDFLAGS-$(target))"
	@echo "BZIP2_SRCDIR-$(target): $$(BZIP2_SRCDIR-$(target))"
	@echo "BZIP2_INSTALL-$(target): $$(BZIP2_INSTALL-$(target))"
	@echo "BZIP2_LIB-$(target): $$(BZIP2_LIB-$(target))"
	@echo "BZIP2_DIST-$(target): $$(BZIP2_DIST-$(target))"
	@echo "XZ_SRCDIR-$(target): $$(XZ_SRCDIR-$(target))"
	@echo "XZ_INSTALL-$(target): $$(XZ_INSTALL-$(target))"
	@echo "XZ_LIB-$(target): $$(XZ_LIB-$(target))"
	@echo "XZ_DIST-$(target): $$(XZ_DIST-$(target))"
	@echo

endef # build-target

###########################################################################
# Build for specified sdk (extracted from the base names in $(TARGETS-*))
###########################################################################
#
# Parameters:
# - $1 sdk (e.g., iphoneos, iphonesimulator)
# - $2 OS (e.g., iOS, tvOS)
#
###########################################################################
define build-sdk
sdk=$1
os=$2

OS_LOWER-$(sdk)=$(shell echo $(os) | tr '[:upper:]' '[:lower:]')

WHEEL_TAG-$(sdk)=py3-none-$$(shell echo $$(OS_LOWER-$(sdk))_$$(VERSION_MIN-$(os))_$(sdk) | sed "s/\./_/g")

SDK_TARGETS-$(sdk)=$$(filter $(sdk).%,$$(TARGETS-$(os)))
SDK_ARCHES-$(sdk)=$$(sort $$(subst .,,$$(suffix $$(SDK_TARGETS-$(sdk)))))

###########################################################################
# SDK: Macro Expansions
###########################################################################

# Expand the build-target macro for target on this OS
$$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(eval $$(call build-target,$$(target),$(os))))

BZip2-$(sdk): $$(foreach target,$$(SDK_TARGETS-$(sdk)),BZip2-$$(target))
XZ-$(sdk): $$(foreach target,$$(SDK_TARGETS-$(sdk)),XZ-$$(target))

###########################################################################
# SDK: Debug
###########################################################################

vars-$(sdk):
	@echo ">>> Environment variables for $(sdk)"
	@echo "SDK_TARGETS-$(sdk): $$(SDK_TARGETS-$(sdk))"
	@echo "SDK_ARCHES-$(sdk): $$(SDK_ARCHES-$(sdk))"
	@echo

endef # build-sdk

###########################################################################
# Build for specified OS (from $(OS_LIST))
###########################################################################
#
# Parameters:
# - $1 - OS (e.g., iOS, tvOS)
#
###########################################################################
define build
os=$1

###########################################################################
# Build: Macro Expansions
###########################################################################

SDKS-$(os)=$$(sort $$(basename $$(TARGETS-$(os))))

# Expand the build-sdk macro for all the sdks on this OS (e.g., iphoneos, iphonesimulator)
$$(foreach sdk,$$(SDKS-$(os)),$$(eval $$(call build-sdk,$$(sdk),$(os))))

BZip2-$(os): $$(foreach sdk,$$(SDKS-$(os)),BZip2-$$(sdk))
XZ-$(os): $$(foreach sdk,$$(SDKS-$(os)),XZ-$$(sdk))

$(os): BZip2-$(os) XZ-$(os)

clean-BZip2-$(os):
	@echo ">>> Clean BZip2 build products on $(os)"
	rm -rf \
		build/$(os)/*/bzip2-$(BZIP2_VERSION) \
		build/$(os)/*/bzip2-$(BZIP2_VERSION).*.log \
		install/$(os)/*/bzip2-$(BZIP2_VERSION) \
		install/$(os)/*/bzip2-$(BZIP2_VERSION).*.log \
		dist/bzip2-$(BZIP2_VERSION)-*

clean-XZ-$(os):
	@echo ">>> Clean XZ build products on $(os)"
	rm -rf \
		build/$(os)/*/xz-$(XZ_VERSION) \
		build/$(os)/*/xz-$(XZ_VERSION).*.log \
		install/$(os)/*/xz-$(XZ_VERSION) \
		install/$(os)/*/xz-$(XZ_VERSION).*.log \
		dist/xz-$(XZ_VERSION)-*

###########################################################################
# Build: Debug
###########################################################################

vars-$(os): $$(foreach target,$$(TARGETS-$(os)),vars-$$(target)) $$(foreach sdk,$$(SDKS-$(os)),vars-$$(sdk))
	@echo ">>> Environment variables for $(os)"
	@echo "SDKS-$(os): $$(SDKS-$(os))"
	@echo

endef # build

# Dump environment variables (for debugging purposes)
vars: $(foreach os,$(OS_LIST),vars-$(os))

# Expand the targets for each product
BZip2: $(foreach os,$(OS_LIST),BZip2-$(os))
XZ: $(foreach os,$(OS_LIST),XZ-$(os))

# Expand the build macro for every OS
$(foreach os,$(OS_LIST),$(eval $(call build,$(os))))
