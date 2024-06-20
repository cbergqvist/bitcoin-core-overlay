# This is based on a gist from 0xB10C.
# Could do with some options for toggling gcc/clang and bitcoin-qt on/off etc.
{ pkgs ? import <nixpkgs> {}
, withGui ? false
, withClang ? false
, withDebug ? false
, withIncompatibleBdb ? false
, withSuppressExternalWarnings ? false }:
let
  inherit (pkgs.lib) optionals;
  baseConfigureFlags = [
    "--with-boost-libdir=\$NIX_BOOST_LIB_DIR"
  ] ++ optionals withClang [
    "CXX=clang++"
    "CC=clang"
  ];

  extendedConfigureFlags = [
  ] ++ optionals withIncompatibleBdb [
    "--with-incompatible-bdb"
  ] ++ optionals withSuppressExternalWarnings [
    "--enable-suppress-external-warnings"
  ] ++ optionals withGui [
    "--with-gui=qt5"
    "--with-qt-bindir=${pkgs.qt5.qtbase.dev}/bin:${pkgs.qt5.qttools.dev}/bin"
  ] ++ optionals withDebug [
    "--enable-debug"
  ];
in
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

      # Berkeley DB 4.8
      db48

      # tests
      hexdump

      # for newer cmake building
      cmake

      # depends
      byacc

      # only needed for older versions
      # openssl

      # functional tests & linting
      python3
      python3Packages.flake8
      python3Packages.lief
      python3Packages.autopep8
      python3Packages.mypy
      python3Packages.requests
      python3Packages.pyzmq

      # benchmarking
      python3Packages.pyperf

      # debugging
      gdb

      # tracing
      libsystemtap
      linuxPackages.bpftrace
      linuxPackages.bcc

      # compiler output caching per
      # https://github.com/bitcoin/bitcoin/blob/master/doc/productivity.md#cache-compilations-with-ccache
      ccache

      # clang-format, clang-tidy
      # reference: https://github.com/bitcoin/bitcoin/blob/master/doc/developer-notes.md#running-clang-tidy
      # $ a && c && m clean && bear --config src/.bear-tidy-config -- make -j $(nproc)
      clang-tools_17
      bear

      # Clang compiler & LLVM debugger
      clang_17
      lldb_17

      # Sublime Text LLDB Debugger made me
      zlib

      ## additional shell niceties
      jq

      # for multiprocess PRs
      libxkbcommon
      fontconfig
      freetype
      xorg.libxcb
      xorg.xcbutilwm
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil
    ] ++ lib.optionals withGui [
      # bitcoin-qt
      qt5.qtbase
      # required for bitcoin-qt for "LRELEASE" etc
      qt5.qttools
    ];

    # needed in 'autogen.sh'
    LIBTOOLIZE = "libtoolize";

    # expose debugger server to editor integrations
    LLDB_DEBUGSERVER_PATH = "${pkgs.lldb_17}/bin/lldb-server";

    # Fixes xcb plugin error when trying to launch bitcoin-qt
    QT_QPA_PLATFORM_PLUGIN_PATH = if withGui then "${pkgs.qt5.qtbase.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins/platforms" else "";

    # needed for 'configure' to find boost
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
      alias c="./configure ${builtins.concatStringsSep " " baseConfigureFlags} ${builtins.concatStringsSep " " extendedConfigureFlags}"
      alias c_no-wallet="./configure --disable-wallet ${builtins.concatStringsSep " " baseConfigureFlags}"
      alias c_fast="./configure --disable-wallet --disable-tests --disable-fuzz --disable-bench -disable-fuzz-binary ${builtins.concatStringsSep " " baseConfigureFlags}"
      alias c_fast_wallet="./configure --disable-tests --disable-bench ${builtins.concatStringsSep " " baseConfigureFlags}"

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
      # assumes prior mounting of /mnt/tmp/ as described in
      # https://github.com/bitcoin/bitcoin/blob/master/test/README.md#speed-up-test-runs-with-a-ram-disk
      alias ftm="ft --cachedir=/mnt/tmp/cache --tmpdir=/mnt/tmp"
      # all tests
      alias t="ut && ftm"

      # additional alias
      alias b="bitcoin-cli"

      echo "adding \$PWD/src to \$PATH to make running built binaries more natural"
      export PATH=$PATH:$PWD/src

      alias a c m c_fast cm acm acm_nw acm_fast ut ft ftm t b
    '';
}