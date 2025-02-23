#
# Useful targets:
# - all             - build everything
# - iOS             - build everything for iOS
# - tvOS            - build everything for tvOS
# - watchOS         - build everything for watchOS
# - BZip2           - build BZip2 for all platforms
# - BZip2-iOS       - build BZip2 for iOS
# - BZip2-tvOS      - build BZip2 for tvOS
# - BZip2-watchOS   - build BZip2 for watchOS
# - XZ              - build XZ for all platforms
# - XZ-iOS          - build XZ for iOS
# - XZ-tvOS         - build XZ for tvOS
# - XZ-watchOS      - build XZ for watchOS
# - OpenSSL         - build OpenSSL for all platforms
# - OpenSSL-iOS     - build OpenSSL for iOS
# - OpenSSL-tvOS    - build OpenSSL for tvOS
# - OpenSSL-watchOS - build OpenSSL for watchOS
# - mpdecimal         - build mpdecimal for all platforms
# - mpdecimal-iOS     - build mpdecimal for iOS
# - mpdecimal-tvOS    - build mpdecimal for tvOS
# - mpdecimal-watchOS - build mpdecimal for watchOS
# - libFFI-iOS      - build libFFI for iOS
# - libFFI-tvOS     - build libFFI for tvOS
# - libFFI-watchOS  - build libFFI for watchOS

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

XZ_VERSION=5.6.4

# Preference is to use OpenSSL 3; however, Cryptography 3.4.8 (and
# probably some other packages as well) only works with 1.1.1, so
# we need to preserve the ability to build the older OpenSSL (for now...)
OPENSSL_VERSION=3.0.16
# OPENSSL_VERSION=1.1.1w
# The Series is the first 2 digits of the version number. (e.g., 1.1.1w -> 1.1)
OPENSSL_SERIES=$(shell echo $(OPENSSL_VERSION) | grep -Eo "\d+\.\d+")

MPDECIMAL_VERSION=4.0.0

LIBFFI_VERSION=3.4.7

CURL_FLAGS=--disable --fail --location --create-dirs --progress-bar

# iOS targets
TARGETS-iOS=iphonesimulator.x86_64 iphonesimulator.arm64 iphoneos.arm64 maccatalyst.x86_64 maccatalyst.arm64
VERSION_MIN-iOS=14.2
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

.PHONY: all clean distclean

# Build for all operating systems
all: $(OS_LIST)

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
ifeq ($(OPENSSL_SERIES),1.1)
	curl $(CURL_FLAGS) -o $@ \
		https://github.com/openssl/openssl/releases/download/OpenSSL_$(shell echo $(OPENSSL_VERSION) | sed "s/\./_/g")/$(notdir $@)
else
	curl $(CURL_FLAGS) -o $@ \
		https://github.com/openssl/openssl/releases/download/openssl-$(OPENSSL_VERSION)/$(notdir $@)
endif

###########################################################################
# Setup: mpdecimal
###########################################################################

# Download original mpdecimal source code archive.
downloads/mpdecimal-$(MPDECIMAL_VERSION).tar.gz:
	@echo ">>> Download mpdecimal sources"
	curl $(CURL_FLAGS) -o $@ \
		https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-$(MPDECIMAL_VERSION).tar.gz


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
SDK-$(target)=$$(subst maccatalyst,macosx,$$(basename $(target)))
ARCH-$(target)=$$(subst .,,$$(suffix $(target)))

ifneq ($$(findstring simulator,$$(SDK-$(target))),)
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))$$(VERSION_MIN-$(os))-simulator
else ifneq ($$(findstring maccatalyst,$$(target)),)
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-ios$$(VERSION_MIN-$(os))-macabi
else
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))$$(VERSION_MIN-$(os))
endif

SDK_ROOT-$(target)=$$(shell xcrun --sdk $$(SDK-$(target)) --show-sdk-path)
CC-$(target)=xcrun --sdk $$(SDK-$(target)) clang -target $$(TARGET_TRIPLE-$(target))
CXX-$(target)=xcrun --sdk $$(SDK-$(target)) clang -target $$(TARGET_TRIPLE-$(target))
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

.PHONY: BZip2-$(target)
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
	cd $$(XZ_SRCDIR-$(target)) && patch -p1 < $(PROJECT_DIR)/patch/xz.patch
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

.PHONY: XZ-$(target)
XZ-$(target): $$(XZ_DIST-$(target))

###########################################################################
# Target: OpenSSL
###########################################################################

OPENSSL_SRCDIR-$(target)=build/$(os)/$(target)/openssl-$(OPENSSL_VERSION)
OPENSSL_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/openssl-$(OPENSSL_VERSION)
OPENSSL_SSL_LIB-$(target)=$$(OPENSSL_INSTALL-$(target))/lib/libssl.a
OPENSSL_DIST-$(target)=dist/openssl-$(OPENSSL_VERSION)-$(BUILD_NUMBER)-$(target).tar.gz

$$(OPENSSL_SRCDIR-$(target))/Configure: downloads/openssl-$(OPENSSL_VERSION).tar.gz
	@echo ">>> Unpack and configure OpenSSL sources for $(target)"
	mkdir -p $$(OPENSSL_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(OPENSSL_SRCDIR-$(target))

ifeq ($(OPENSSL_SERIES),1.1)
	# Patch OpenSSL 1.1.X sources
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_SRCDIR-$(target))/apps/speed.c
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_SRCDIR-$(target))/apps/ocsp.c
else
	# Patch OpenSSL 3.X.X sources
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_SRCDIR-$(target))/apps/include/http_server.h
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_SRCDIR-$(target))/apps/speed.c
endif

	# Touch the Configure script to ensure that Make identifies it as up to date.
	touch $$(OPENSSL_SRCDIR-$(target))/Configure


$$(OPENSSL_SRCDIR-$(target))/is_configured: $$(OPENSSL_SRCDIR-$(target))/Configure
	# Configure the OpenSSL build
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		./Configure iphoneos-cross no-asm no-tests \
			--prefix="$$(OPENSSL_INSTALL-$(target))" \
			--openssldir=/etc/ssl \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).config.log

	# The OpenSSL Makefile is... interesting. Invoking `make all` or `make
	# install` *modifies the Makefile*. Therefore, we can't use the Makefile as
	# a build dependency, because building/installing dirties the target that
	# was used as a dependency. To compensate, create a dummy file as a marker
	# for whether OpenSSL has been configured, and use *that* as a reference.
	date > $$(OPENSSL_SRCDIR-$(target))/is_configured

$$(OPENSSL_SRCDIR-$(target))/libssl.a: $$(OPENSSL_SRCDIR-$(target))/is_configured
	@echo ">>> Build OpenSSL for $(target)"
	# OpenSSL's `all` target modifies the Makefile;
	# use the raw targets that make up all and it's dependencies
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make build_sw \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).build.log

$$(OPENSSL_SSL_LIB-$(target)): $$(OPENSSL_SRCDIR-$(target))/libssl.a
	@echo ">>> Install OpenSSL for $(target)"
	# Install just the software (not the docs)
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make install_sw \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).install.log

$$(OPENSSL_DIST-$(target)): $$(OPENSSL_SSL_LIB-$(target))
	@echo ">>> Build OpenSSL distribution for $(target)"
	mkdir -p dist

	cd $$(OPENSSL_INSTALL-$(target)) && tar zcvf $(PROJECT_DIR)/$$(OPENSSL_DIST-$(target)) lib include

.PHONY: OpenSSL-$(target)
OpenSSL-$(target): $$(OPENSSL_DIST-$(target))

###########################################################################
# Target: mpdecimal
###########################################################################

MPDECIMAL_SRCDIR-$(target)=build/$(os)/$(target)/mpdecimal-$(MPDECIMAL_VERSION)
MPDECIMAL_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/mpdecimal-$(MPDECIMAL_VERSION)
MPDECIMAL_LIB-$(target)=$$(MPDECIMAL_INSTALL-$(target))/lib/libmpdec.a
MPDECIMAL_DIST-$(target)=dist/mpdecimal-$(MPDECIMAL_VERSION)-$(BUILD_NUMBER)-$(target).tar.gz

$$(MPDECIMAL_SRCDIR-$(target))/configure: downloads/mpdecimal-$(MPDECIMAL_VERSION).tar.gz
	@echo ">>> Unpack mpdecimal sources for $(target)"
	mkdir -p $$(MPDECIMAL_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(MPDECIMAL_SRCDIR-$(target))
	# Patch the source to add support for new platforms
	cd $$(MPDECIMAL_SRCDIR-$(target)) && patch -p1 < $(PROJECT_DIR)/patch/mpdecimal.patch
	# Touch the configure script to ensure that Make identifies it as up to date.
	touch $$(MPDECIMAL_SRCDIR-$(target))/configure

$$(MPDECIMAL_SRCDIR-$(target))/Makefile: $$(MPDECIMAL_SRCDIR-$(target))/configure
	# Configure the build
	cd $$(MPDECIMAL_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		./configure \
			CC="$$(CC-$(target))" \
			CXX="$$(CXX-$(target))" \
			CFLAGS="$$(CFLAGS-$(target))" \
			LDFLAGS="$$(LDFLAGS-$(target))" \
			--disable-shared \
			--enable-static \
			--host=$$(TARGET_TRIPLE-$(target)) \
			--build=$(HOST_ARCH)-apple-darwin \
			--prefix="$$(MPDECIMAL_INSTALL-$(target))" \
			2>&1 | tee -a ../xz-$(MPDECIMAL_VERSION).config.log

$$(MPDECIMAL_LIB-$(target)): $$(MPDECIMAL_SRCDIR-$(target))/Makefile
	@echo ">>> Build and install MPDECIMAL for $(target)"
	cd $$(MPDECIMAL_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		make install \
			2>&1 | tee -a ../xz-$(MPDECIMAL_VERSION).build.log

$$(MPDECIMAL_DIST-$(target)): $$(MPDECIMAL_LIB-$(target))
	@echo ">>> Build MPDECIMAL distribution for $(target)"
	mkdir -p dist

	cd $$(MPDECIMAL_INSTALL-$(target)) && tar zcvf $(PROJECT_DIR)/$$(MPDECIMAL_DIST-$(target)) lib include

.PHONY: mpdecimal-$(target)
mpdecimal-$(target): $$(MPDECIMAL_DIST-$(target))

###########################################################################
# Target: libFFI
###########################################################################

# The configure step is performed as part of the OS-level build.

LIBFFI_SRCDIR-$(os)=build/$(os)/libffi-$(LIBFFI_VERSION)
LIBFFI_SRCDIR-$(target)=$$(LIBFFI_SRCDIR-$(os))/build_$$(SDK-$(target))-$$(ARCH-$(target))
LIBFFI_BUILD_LIB-$(target)=$$(LIBFFI_SRCDIR-$(target))/.libs/libffi.a
LIBFFI_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/libffi-$(LIBFFI_VERSION)
LIBFFI_LIB-$(target)=$$(LIBFFI_INSTALL-$(target))/lib/libffi.a
LIBFFI_DIST-$(target)=dist/libffi-$(LIBFFI_VERSION)-$(BUILD_NUMBER)-$(target).tar.gz

$$(LIBFFI_BUILD_LIB-$(target)): $$(LIBFFI_SRCDIR-$(os))/darwin_common/include/ffi.h
	@echo ">>> Build libFFI for $(target)"
	cd $$(LIBFFI_SRCDIR-$(target)) && \
		make \
			2>&1 | tee -a ../../libffi-$(LIBFFI_VERSION).build.log

$$(LIBFFI_LIB-$(target)): $$(LIBFFI_BUILD_LIB-$(target))
	@echo ">>> Install libFFI for $(target)"
	mkdir -p $$(LIBFFI_INSTALL-$(target))/lib
	cp $$(LIBFFI_BUILD_LIB-$(target)) $$(LIBFFI_LIB-$(target))

	# Copy the set of platform headers
	cp -f -r $$(LIBFFI_SRCDIR-$(os))/darwin_common/include \
		$$(LIBFFI_INSTALL-$(target))
	cp -f -r $$(LIBFFI_SRCDIR-$(os))/darwin_$$(OS_LOWER-$(sdk))/include/* \
		$$(LIBFFI_INSTALL-$(target))/include

$$(LIBFFI_DIST-$(target)): $$(LIBFFI_LIB-$(target))
	@echo ">>> Build libFFI distribution for $(target)"
	mkdir -p dist

	cd $$(LIBFFI_INSTALL-$(target)) && tar zcvf $(PROJECT_DIR)/$$(LIBFFI_DIST-$(target)) lib include

.PHONY: libFFI-$(target)
libFFI-$(target): $$(LIBFFI_DIST-$(target))

###########################################################################
# Target: Debug
###########################################################################

.PHONY: vars-$(target)
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
	@echo "OPENSSL_SRCDIR-$(target): $$(OPENSSL_SRCDIR-$(target))"
	@echo "OPENSSL_INSTALL-$(target): $$(OPENSSL_INSTALL-$(target))"
	@echo "OPENSSL_SSL_LIB-$(target): $$(OPENSSL_SSL_LIB-$(target))"
	@echo "OPENSSL_DIST-$(target): $$(OPENSSL_DIST-$(target))"
	@echo "MPDECIMAL_SRCDIR-$(target): $$(MPDECIMAL_SRCDIR-$(target))"
	@echo "MPDECIMAL_INSTALL-$(target): $$(MPDECIMAL_INSTALL-$(target))"
	@echo "MPDECIMAL_LIB-$(target): $$(MPDECIMAL_LIB-$(target))"
	@echo "MPDECIMAL_DIST-$(target): $$(MPDECIMAL_DIST-$(target))"
	@echo "LIBFFI_SRCDIR-$(target): $$(LIBFFI_SRCDIR-$(target))"
	@echo "LIBFFI_BUILD_LIB-$(target): $$(LIBFFI_BUILD_LIB-$(target))"
	@echo "LIBFFI_INSTALL-$(target): $$(LIBFFI_INSTALL-$(target))"
	@echo "LIBFFI_LIB-$(target): $$(LIBFFI_LIB-$(target))"
	@echo "LIBFFI_DIST-$(target): $$(LIBFFI_DIST-$(target))"
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

.PHONY: BZip2-$(sdk) XZ-$(sdk) OpenSSL-$(sdk) libFFI-$(sdk)
BZip2-$(sdk): $$(foreach target,$$(SDK_TARGETS-$(sdk)),BZip2-$$(target))
XZ-$(sdk): $$(foreach target,$$(SDK_TARGETS-$(sdk)),XZ-$$(target))
OpenSSL-$(sdk): $$(foreach target,$$(SDK_TARGETS-$(sdk)),OpenSSL-$$(target))
mpdecimal-$(sdk): $$(foreach target,$$(SDK_TARGETS-$(sdk)),mpdecimal-$$(target))
libFFI-$(sdk): $$(foreach target,$$(SDK_TARGETS-$(sdk)),libFFI-$$(target))

###########################################################################
# SDK: Debug
###########################################################################

.PHONY: vars-$(sdk)
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

SDKS-$(os)=$$(sort $$(basename $$(TARGETS-$(os))))

# Expand the build-sdk macro for all the sdks on this OS (e.g., iphoneos, iphonesimulator)
$$(foreach sdk,$$(SDKS-$(os)),$$(eval $$(call build-sdk,$$(sdk),$(os))))

###########################################################################
# Build: libFFI
###########################################################################

$$(LIBFFI_SRCDIR-$(os))/darwin_common/include/ffi.h: downloads/libffi-$(LIBFFI_VERSION).tar.gz
	@echo ">>> Unpack and configure libFFI sources on $(os)"
	mkdir -p $$(LIBFFI_SRCDIR-$(os))
	tar zxf $$< --strip-components 1 -C $$(LIBFFI_SRCDIR-$(os))
	# Patch the source to add support for maccatalyst/remove i386+armv7
	cd $$(LIBFFI_SRCDIR-$(os)) && patch -p1 < $(PROJECT_DIR)/patch/libffi.patch
	# Configure the build
	cd $$(LIBFFI_SRCDIR-$(os)) && \
		python3 generate-darwin-source-and-headers.py --only-$(shell echo $(os) | tr '[:upper:]' '[:lower:]') --disable-i386 --disable-armv7 \
		2>&1 | tee -a ../libffi-$(LIBFFI_VERSION).config.log

###########################################################################
# Build: Macro Expansions
###########################################################################

.PHONY: BZip2-$(os) XZ-$(os) OpenSSL-$(os) libFFI-$(os)
BZip2-$(os): $$(foreach sdk,$$(SDKS-$(os)),BZip2-$$(sdk))
XZ-$(os): $$(foreach sdk,$$(SDKS-$(os)),XZ-$$(sdk))
OpenSSL-$(os): $$(foreach sdk,$$(SDKS-$(os)),OpenSSL-$$(sdk))
mpdecimal-$(os): $$(foreach sdk,$$(SDKS-$(os)),mpdecimal-$$(sdk))
libFFI-$(os): $$(foreach sdk,$$(SDKS-$(os)),libFFI-$$(sdk))

.PHONY: clean-BZip2-$(os) clean-XZ-$(os) clean-OpenSSL-$(os) clean-mpdecimal-$(os) clean-libFFI-$(os)
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

clean-OpenSSL-$(os):
	@echo ">>> Clean OpenSSL build products on $(os)"
	rm -rf \
		build/$(os)/*/openssl-$(OPENSSL_VERSION) \
		build/$(os)/*/openssl-$(OPENSSL_VERSION).*.log \
		install/$(os)/*/openssl-$(OPENSSL_VERSION) \
		install/$(os)/*/openssl-$(OPENSSL_VERSION).*.log \
		dist/openssl-$(OPENSSL_VERSION)-*

clean-mpdecimal-$(os):
	@echo ">>> Clean mpdecimal build products on $(os)"
	rm -rf \
		build/$(os)/*/mpdecimal-$(MPDECIMAL_VERSION) \
		build/$(os)/*/mpdecimal-$(MPDECIMAL_VERSION).*.log \
		install/$(os)/*/mpdecimal-$(MPDECIMAL_VERSION) \
		install/$(os)/*/mpdecimal-$(MPDECIMAL_VERSION).*.log \
		dist/mpdecimal-$(MPDECIMAL_VERSION)-*

clean-libFFI-$(os):
	@echo ">>> Clean libFFI build products on $(os)"
	rm -rf \
		build/$(os)/*/libffi-$(LIBFFI_VERSION) \
		build/$(os)/*/libffi-$(LIBFFI_VERSION).*.log \
		install/$(os)/*/libffi-$(LIBFFI_VERSION) \
		install/$(os)/*/libffi-$(LIBFFI_VERSION).*.log \
		dist/libffi-$(LIBFFI_VERSION)-*

.PHONY: $(os)
$(os): BZip2-$(os) XZ-$(os) OpenSSL-$(os) mpdecimal-$(os) libFFI-$(os)

###########################################################################
# Build: Debug
###########################################################################

.PHONY: vars-$(os)
vars-$(os): $$(foreach target,$$(TARGETS-$(os)),vars-$$(target)) $$(foreach sdk,$$(SDKS-$(os)),vars-$$(sdk))
	@echo ">>> Environment variables for $(os)"
	@echo "SDKS-$(os): $$(SDKS-$(os))"
	@echo "LIBFFI_SRCDIR-$(os): $$(LIBFFI_SRCDIR-$(os))"
	@echo

endef # build

# Dump environment variables (for debugging purposes)
.PHONY: vars
vars: $(foreach os,$(OS_LIST),vars-$(os))

# Expand the targets for each product
.PHONY: BZip2 XZ OpenSSL mpdecimal libFFI
BZip2: $(foreach os,$(OS_LIST),BZip2-$(os))
XZ: $(foreach os,$(OS_LIST),XZ-$(os))
OpenSSL: $(foreach os,$(OS_LIST),OpenSSL-$(os))
mpdecimal: $(foreach os,$(OS_LIST),mpdecimal-$(os))
libFFI: $(foreach os,$(OS_LIST),libFFI-$(os))

clean-BZip2: $(foreach os,$(OS_LIST),clean-BZip2-$(os))
clean-XZ: $(foreach os,$(OS_LIST),clean-XZ-$(os))
clean-OpenSSL: $(foreach os,$(OS_LIST),clean-OpenSSL-$(os))
clean-mpdecimal: $(foreach os,$(OS_LIST),clean-mpdecimal-$(os))
clean-libFFI: $(foreach os,$(OS_LIST),clean-libFFI-$(os))

# Expand the build macro for every OS
$(foreach os,$(OS_LIST),$(eval $(call build,$(os))))
