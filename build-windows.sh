#!/usr/bin/env bash

# Copyright 2022-2024 Google LLC.
# SPDX-License-Identifier: Apache-2.0

set -e

if ! uname | grep -q 'MINGW64_NT'; then
  echo 'This script should run on MSYS2 bash'
  echo
  exit 1
fi

export MSYS=winsymlinks:nativestrict

. common.sh

OS='windows'
NDK_DIRNAME='windows-x86_64'
TRIPLE='x86_64-pc-windows-gnu'
DYN_EXT='dll'
PYTHON_CMD='python'
MINGW_URL='https://github.com/niXman/mingw-builds-binaries/releases/download/13.2.0-rt_v11-rev1/x86_64-13.2.0-release-win32-seh-ucrt-rt_v11-rev1.7z'

clean_storage() {
  # Clean up storage to fit in all our build output
  rm -rf /c/SeleniumWebDrivers /c/selenium /c/Android /c/tools /c/Modules \
    '/c/Program Files/PostgreSQL' '/c/Program Files/dotnet' \
    "$JAVA_HOME_8_X64" "$JAVA_HOME_11_X64" "$JAVA_HOME_17_X64" \
    "$GOROOT_1_15_X64" "$GOROOT_1_16_X64" "$GOROOT_1_17_X64" "$GOROOT_1_18_X64"
}

replace_cp() {
  local src=$1
  local dest=$2

  for d in $dest/*; do
    local s=$src/$(basename $d)
    if [ -L $s ]; then
      # It is possible that the symlink is pointing to a new file, copy it first
      local s_real=$(realpath $s)
      local d_real=$dest/$(basename $s_real)
      cp -af $s_real $d_real
      # Then create the symlink
      local path=$(readlink $s)
      ln -sf $path $d
    elif [ -f $s ]; then
      cp -af $s $d
    fi
  done
}

build() {
  cd rust
  python ./x.py --config '../config-windows.toml' --build $TRIPLE install
  cd ../

  cd out
  find . -name '*.old' -delete
  cp -af ../rust/build/$TRIPLE/llvm/bin llvm-bin || true
  cp -an ../rust/build/$TRIPLE/llvm/bin/. llvm-bin/.
  cp -af lib/rustlib/$TRIPLE/bin/rust-lld.exe llvm-bin/lld.exe
  cd ..
}

ndk() {
  dl_ndk

  # Copy the whole output folder into ndk
  cp -af out ndk/toolchains/rust || true
  cp -an out/. ndk/toolchains/rust/.

  cd ndk/toolchains

  local LLVM_DIR=llvm/prebuilt/$NDK_DIRNAME

  # Replace files with those from the rust toolchain
  replace_cp rust/llvm-bin $LLVM_DIR/bin
  cp -af rust/llvm-bin/lld.exe $LLVM_DIR/bin/lld.exe
  ln -sf lld.exe $LLVM_DIR/bin/ld.exe
  ln -sf lld.exe $LLVM_DIR/bin/ld.lld.exe
  rm -rf rust/llvm-bin

  cd ../..

  # Bundle the entire mingw toolchain
  curl -o mingw.7z -OL "$MINGW_URL"
  7z x mingw.7z
  cp -af mingw64/. ndk/toolchains/rust/.
}

export PATH='/c/Program Files/Git/cmd':$PATH

if [ -n "$GITHUB_ACTION" ]; then
  clean_storage
fi

parse_args $@
