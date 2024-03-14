{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
    nativeBuildInputs = with pkgs; [
      autoconf
      automake
      libtool
      pkg-config
      boost
      libevent
      zeromq
      sqlite
      db48

      # multiprocess
      libxkbcommon
      fontconfig
      freetype
      xorg.libxcb
      xorg.xcbutilwm
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil

      # tests
      hexdump

      # for newer cmake building
      cmake

      # depends
      byacc

      # only needed for older versions
      # openssl

      # functional tests
      python3
      python39Packages.flake8
      python39Packages.lief
      python3Packages.flake8
      python3Packages.autopep8
      python39Packages.mypy
      python3Packages.requests
      python3Packages.pyzmq
      python39Packages.pyzmq

      # benchmarking
      python3Packages.pyperf

      # debugging
      gdb

      # tracing
      libsystemtap
      linuxPackages.bpftrace
      linuxPackages.bcc

      # compiler output caching
      ccache

      # clang-format
      clang-tools_17
      #clang++ <-- used before needing clang-tidy
      # https://github.com/bitcoin/bitcoin/blob/master/doc/developer-notes.md#running-clang-tidy
      # $ a && c && m clean && bear --config src/.bear-tidy-config -- make -j $(nproc)
      clang_17
      lldb_17
      bear

      # bitcoin-qt
      qt5.qtbase
      qt5.qttools # for lrelease

      # Sublime Text LLDB Debugger made me
      zlib

      ## additional shell niceties
      jq
    ];

    # needed in 'autogen.sh'
    LIBTOOLIZE = "libtoolize";

    # Fixes xcb plugin error when trying to launch bitcoin-qt
    QT_QPA_PLATFORM_PLUGIN_PATH = "${pkgs.qt5.qtbase.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins/platforms";

    # needed for 'configure' to find boost
    # Run ./configure with the argument '--with-boost-libdir=\$NIX_BOOST_LIB_DIR'"
    NIX_BOOST_LIB_DIR = "${pkgs.boost}/lib";

    shellHook = ''
      echo "Bitcoin Core build nix-shell"
      echo ""

      BCC_EGG=${pkgs.linuxPackages.bcc}/lib/python3.11/site-packages/bcc-0.29.1-py3.11.egg

      echo "adding bcc egg to PYTHONPATH: $BCC_EGG"
      if [ -f $BCC_EGG ]; then
        export PYTHONPATH="$PYTHONPATH:$BCC_EGG"
        echo ""
      else
        echo "The bcc egg $BCC_EGG does not exist. Maybe the python or bcc version is different?"
      fi

      # autogen
      alias a="sh autogen.sh"

      # configure
      # Using Clang instead of GCC after tip from Josi Bake that it finds shadowed variables better.
      alias c="./configure --with-boost-libdir=\$NIX_BOOST_LIB_DIR CXX=clang++ CC=clang CXXFLAGS=\"-O0 -g\" CFLAGS=\"-O0 -g\" --enable-debug"
      alias c_no-wallet="./configure --with-boost-libdir=\$NIX_BOOST_LIB_DIR --disable-wallet CXX=clang++ CC=clang"
      alias c_fast="./configure --with-boost-libdir=\$NIX_BOOST_LIB_DIR --disable-wallet --disable-tests --disable-fuzz --disable-bench -disable-fuzz-binary CXX=clang++ CC=clang"
      alias c_fast_wallet="./configure --with-boost-libdir=\$NIX_BOOST_LIB_DIR --disable-tests --disable-bench CXX=clang++ CC=clang"

      # make
      alias m="make -j"$(($(nproc)+1))

      # configure + make combos
      alias cm="c && m"
      alias cm_fast="c_fast && m"

      # autogen + configure + make combos
      alias acm="a && c && m"
      alias acm_nw="a && c_no-wallet && m"
      alias acm_fast="a && c_fast && m"
      alias acm_fast_wallet="a && c_fast_wallet && m"

      # tests
      alias ut="make check"
      # functional tests
      alias ft="python3 test/functional/test_runner.py"
      # all tests
      alias t="ut && ft"

      # additional alias
      alias b="bitcoin-cli"

      export PATH=$PATH:$PWD/src
      export LLDB_DEBUGSERVER_PATH=${pkgs.lldb_17}/bin/lldb-server

      alias a b c m c_fast cm acm acm_nw acm_fast ut ft t
    '';
}