#!/usr/bin/env bash
source "$(dirname "$0")/tool-variables"

if [ "$OS_CHECK" == "Darwin" ]
then
  CORE_COUNT=$(sysctl -n hw.ncpu)
else
  CORE_COUNT=$(nproc)
fi

# deps: (there might be something missing here)
# libmpc texinfo git make java makeinfo

deps_check() {
  for i in "git" "make" "wget" "makeinfo"
  do
    if [ "$(which $i)" == "" ]
    then
      echo "$i is not installed"
      if [ "$i" == "makeinfo" ]
      then
        echo "install texinfo or something like that"
      fi
      exit
    fi
  done
  if [ "$OS_CHECK" == "Darwin" ]
  then
    if [ "$(which gcc-13)" == "" ]
    then
      echo "gcc-13 not installed"
      echo "brew install gcc@13"
      exit
    fi
  fi
}

clean_build() {
  if [ ! -d $BASE_BUILD_DIR ]
  then
    mkdir $BASE_BUILD_DIR
  fi
  if [ -d $M68K_GCC_TOOLCHAIN ]
  then
    rm -rf $M68K_GCC_TOOLCHAIN
  fi
}

build_toolchain() {
  cd $BASE_BUILD_DIR
  export PATH=$M68K_GCC_TOOLCHAIN/bin:$PATH
  mkdir -p ${M68K_GCC_TOOLCHAIN}/{src,build}
  cd ${M68K_GCC_TOOLCHAIN}/src
  wget $BINUTILS_URL
  echo "extracting binutils..."
  tar -xzf $BINUTILS_FILE
  rm $BINUTILS_FILE
  
  wget $GCC_URL
  echo "extracting gcc..."
  tar -xzf $GCC_FILE
  rm $GCC_FILE

  cd ${GCC_DIR}
  echo "downloading deps..."
  ./contrib/download_prerequisites
  mkdir ${M68K_GCC_TOOLCHAIN}/build/${BINUTILS_DIR}
  cd ${M68K_GCC_TOOLCHAIN}/build/${BINUTILS_DIR}
  if [ "$OS_CHECK" == "Darwin" ]
  then
    export CC=gcc-13
    export CXX=g++-13
  fi
  CONFIG_STUFFS="--without-headers --without-newlib"
  ${M68K_GCC_TOOLCHAIN}/src/${BINUTILS_DIR}/configure \
    --target=m68k-elf \
    --prefix=$M68K_GCC_TOOLCHAIN \
    --disable-nls --disable-werror \
    $CONFIG_STUFFS
  make -j$CORE_COUNT
  make install
  mkdir ${M68K_GCC_TOOLCHAIN}/build/${GCC_DIR}
  cd ${M68K_GCC_TOOLCHAIN}/build/${GCC_DIR}
  ${M68K_GCC_TOOLCHAIN}/src/${GCC_DIR}/configure \
    --target=m68k-elf \
    --prefix=$M68K_GCC_TOOLCHAIN \
    --enable-languages=c \
    $CONFIG_STUFFS \
    --disable-shared \
    --disable-libstdcxx \
    --disable-threads \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libmudflap \
    --disable-nls \
    --with-cpu=68000

  make -j$CORE_COUNT all-gcc
  make -j$CORE_COUNT all-target-libgcc
  make install-gcc
  make install-target-libgcc

  cd ${M68K_GCC_TOOLCHAIN}
  rm -rf build
  rm -rf src
  find $M68K_GCC_TOOLCHAIN -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true
  find $M68K_GCC_TOOLCHAIN -name '*.a' -exec strip -g {} + 2>/dev/null || true
}

deps_check

clean_build
build_toolchain
PATH=${M68K_GCC_TOOLCHAIN}/bin:$PATH
echo ""
echo "----------------------------------------------------"
echo "add tools to path:"
echo "${M68K_GCC_TOOLCHAIN}/bin"
echo ""
echo "----------------------------------------------------"
