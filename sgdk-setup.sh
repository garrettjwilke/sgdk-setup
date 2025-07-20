#!/usr/bin/env bash
source "$(dirname "$0")/tool-variables"

SJASM_SRC=${GDK}/Sjasm/Sjasm
SJASM_VERSION="v0.39" # for some reason this version works for x86 linux

if [ "$OS_CHECK" == "Darwin" ]
then
  CORE_COUNT=$(sysctl -n hw.ncpu)
else
  CORE_COUNT=$(nproc)
fi

# deps: (there might be something missing here)
# libmpc texinfo git make java makeinfo

deps_check() {
  for i in "git" "make" "java" "makeinfo"
  do
    if [ "$(which $i)" == "" ]
    then
      echo "$i is not installed"
      if [ "$i" == "java" ]
      then
        echo "install openjdk-11-jre or something like that"
      elif [ "$i" == "makeinfo" ]
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
      echo "brew install gcc@13"
      echo "then open a new terminal"
      exit
    fi
  fi
  if [ ! -d $M68K_GCC_TOOLCHAIN ]
  then
    echo ""
    echo "gcc toolchain not installed? build toolchain first."
    echo ""
    exit
  fi
  if [ ! -f ${M68K_GCC_TOOLCHAIN}/bin/m68k-elf-gcc ]
  then
    echo ""
    echo "gcc toolchain not installed? build toolchain first."
    echo ""
    exit
  fi
}

clean_build() {
  if [ ! -d $BASE_BUILD_DIR ]
  then
    mkdir $BASE_BUILD_DIR
  fi

  if [ -d $GDK ]
  then
    rm -rf $GDK
  fi

  cd $BASE_BUILD_DIR
  git clone https://github.com/Stephane-D/SGDK.git --depth=1
  cd $GDK
  git checkout $GDK_VERSION
  git clone https://github.com/Konamiman/Sjasm
  cd Sjasm
  git checkout $SJASM_VERSION
  cd $GDK
}

build_sjasm() {
  cd $SJASM_SRC
  make clean
  if [ "$OS_CHECK" == "Darwin" ]
  then
    export CXX=/usr/bin/g++
    export CC=/usr/bin/gcc
  fi
  make sjasm -j$CORE_COUNT
  if [ ! -f sjasm ]
  then
    echo "sjasm build failed?"
    exit
  fi
  cp sjasm ${GDK}/bin/sjasm
}

build_sgdktools() {
  cd $GDK/tools/xgmtool
  gcc src/*.c -Wall -O2 -lm -o xgmtool
  strip xgmtool
  cp xgmtool ${GDK}/bin/
  cd $GDK/tools/bintos
  gcc src/bintos.c -Wall -O2 -o bintos
  strip bintos
  cp bintos ${GDK}/bin/
  cd ${GDK}/tools/convsym
  make -j$CORE_COUNT
  cp build/convsym ${GDK}/bin/
}

deps_check
clean_build
build_sjasm
PATH=${GDK}/bin:$PATH 
build_sgdktools
PATH=${M68K_GCC_TOOLCHAIN}/bin:$PATH
cd $GDK
make -f makelib.gen clean-release
make -f makelib.gen release
make -f makelib.gen clean-debug
make -f makelib.gen debug
echo ""
echo "----------------------------------------------------"
echo "add tools to path:"
echo "${GDK}/bin"
echo ""
echo "build project with:"
echo "make -f ${GDK}/makefile.gen"
echo ""
