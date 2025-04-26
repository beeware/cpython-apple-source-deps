CPython Apple source dependencies
=================================

A meta-package for building the binary packages for iOS, tvOS, watchOS, and
visionOS that a CPython build requires. This includes:

* BZip2
* XZ
* libFFI
* mpdecimal
* OpenSSL 1.1
* OpenSSL 3.0

The repository works by downloading, patching, and building binaries for each
SDK target and architecture that is requried. The compiled library is packed
into a tarball for distribution in "installed" form - that is, the contents of
the ``include`` and ``lib`` folders are included.

The binaries support arm64 for iOS, appleTV and visionOS devices, and arm64_32
for watchOS. They also supports device simulators on both x86_64 and arm64
hardware, except that visionOS is officially unsupported by Apple on x86_64.
This should enable the code to run on:

* iOS 13.0 or later, on:
    * iPhone (6s or later)
    * iPad (5th gen or later)
    * iPad Air (all models)
    * iPad Mini (2 or later)
    * iPad Pro (all models)
    * iPod Touch (7th gen or later)
* Mac Catalyst 14.2 (macOS 11) or later, on:
    * MacBook (2015 or later)
    * MacBook Air (2013 or later)
    * MacBook Pro (Late 2013 or later)
    * Mac mini (2014 or later)
    * iMac (2014 or later)
    * iMac Pro (2017 or later)
    * Mac Pro (2013 or later)
    * Mac Studio
* tvOS 9.0 or later, on:
    * Apple TV (4th gen or later)
* watchOS 4.0 or later, on:
    * Apple Watch (4th gen or later)
* visionOS 2.0 or later, on:
    * Apple Vision Pro (all models)

Quickstart
----------

**Unless you're trying to directly link against one of these libraries, you
don't need to use this repository**. When you obtain a CPython build for an
Apple platform, it will have already been linked using these libraries.

If you *do* need to link against these libraries for some reason, you can use
the pre-compiled versions that are published on the `Github releases page
<https://github.com/beeware/cpython-apple-source-deps/releases>`__. You don't
need to compile them yourself.

However, if you *do* need to compile your own version for some reason:

* Clone this repository
* Create a Python 3 virtual environment. Any supported Python 3 release should
  be sufficient; some tools require python3 as part of their build.
* In the root directory, run:
  - ``make`` (or ``make all``) to build everything.
  - ``make iOS`` to build everything for iOS.
  - ``make BZip2`` to build BZip2 for every platform
  - ``make BZip2-iOS`` to build BZip2 for iOS

This should:

1. Download the original source packages
2. Patch them as required for compatibility with the selected OS
3. Build the libraries for the selected OS and architecture
4. Package a tarball containing build products.

The resulting artefacts will be packaged as ``.tar.gz`` files in the ``dist``
folder.
