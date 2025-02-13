#!/bin/bash
# 002-gcc-stage1.sh by ps2dev developers

## Exit with code 1 when any command executed returns a non-zero exit code.
onerr()
{
  exit 1;
}
trap onerr ERR

## Read information from the configuration file.
source "$(dirname "$0")/../config/ps2toolchain-iop-config.sh"

## Download the source code.
REPO_URL="$PS2TOOLCHAIN_IOP_GCC_REPO_URL"
REPO_REF="$PS2TOOLCHAIN_IOP_GCC_DEFAULT_REPO_REF"
REPO_FOLDER="$(s="$REPO_URL"; s=${s##*/}; printf "%s" "${s%.*}")"

# Checking if a specific Git reference has been passed in parameter $1
if test -n "$1"; then
  REPO_REF="$1"
  printf 'Using specified repo reference %s\n' "$REPO_REF"
fi

if test ! -d "$REPO_FOLDER"; then
  git clone --depth 1 -b "$REPO_REF" "$REPO_URL" "$REPO_FOLDER"
else
  git -C "$REPO_FOLDER" fetch origin
  git -C "$REPO_FOLDER" reset --hard "origin/$REPO_REF"
  git -C "$REPO_FOLDER" checkout "$REPO_REF"
fi

cd "$REPO_FOLDER"

TARGET_ALIAS="iop"
TARG_XTRA_OPTS=""
OSVER=$(uname)

# Workaround to build with newer mingw-w64 https://github.com/msys2/MINGW-packages/commit/4360ed1a7470728be1dba0687df764604f1992d9
if [ "${OSVER:0:10}" == MINGW64_NT ]; then
  export lt_cv_sys_max_cmd_len=8000
  export CC=x86_64-w64-mingw32-gcc
  TARG_XTRA_OPTS="--host=x86_64-w64-mingw32"
  export CPPFLAGS="-DWIN32_LEAN_AND_MEAN -DCOM_NO_WINDOWS_H"
elif [ "${OSVER:0:10}" == MINGW32_NT ]; then
  export lt_cv_sys_max_cmd_len=8000
  export CC=i686-w64-mingw32-gcc
  TARG_XTRA_OPTS="--host=i686-w64-mingw32"
  export CPPFLAGS="-DWIN32_LEAN_AND_MEAN -DCOM_NO_WINDOWS_H"
fi

## Determine the maximum number of processes that Make can work with.
PROC_NR=$(getconf _NPROCESSORS_ONLN)

## For each target...
for TARGET in "mipsel-ps2-irx" "mipsel-ps2-elf"; do
  ## Create and enter the toolchain/build directory
  rm -rf "build-$TARGET-stage1"
  mkdir "build-$TARGET-stage1"
  cd "build-$TARGET-stage1"

  ## Configure the build.
  ../configure \
    --quiet \
    --prefix="$PS2DEV/$TARGET_ALIAS" \
    --target="$TARGET" \
    --enable-languages="c" \
    --with-float=soft \
    --with-headers=no \
    --without-newlib \
    --without-cloog \
    --without-ppl \
    --disable-decimal-float \
    --disable-libada \
    --disable-libatomic \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libstdcxx-pch \
    --disable-multilib \
    --disable-shared \
    --disable-threads \
    --disable-target-libiberty \
    --disable-target-zlib \
    --disable-nls \
    --disable-tls \
    MAKEINFO=missing \
    $TARG_XTRA_OPTS

  ## Compile and install.
  make --quiet -j "$PROC_NR" MAKEINFO=missing all
  make --quiet -j "$PROC_NR" MAKEINFO=missing install-strip
  make --quiet -j "$PROC_NR" MAKEINFO=missing clean

  ## Exit the build directory.
  cd ..

  ## End target.
done
