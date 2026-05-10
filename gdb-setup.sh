#!/usr/bin/env bash

# requires libgmp libmpfr bison libncurses-dev

# sometimes gdb._execute_unwinders error....to fix:
#   cd gdb-16.2/gdb/data-directory
#   make install

source "$(dirname "$0")/tool-variables"

if [ "$OS_CHECK" == "Darwin" ]
then
  CORE_COUNT=$(sysctl -n hw.ncpu)
  COMPILE_FLAGS="--with-gmp=$(brew --prefix gmp) --with-mpfr=$(brew --prefix mpfr) --with-system-zlib"
else
  CORE_COUNT=$(nproc)
  COMPILE_FLAGS=""
fi

if [ ! -d $M68K_GCC_TOOLCHAIN ]
then
  echo "run gcc-toolchain-setup.sh first"
  exit
fi

cd $M68K_GCC_TOOLCHAIN
if [ -f ${GDB_FILE} ]
then
  rm ${GDB_FILE}
fi
if [ -d ${GDB_DIR} ]
then
  rm -rf ${GDB_DIR}
fi
wget $GDB_URL
if [ ! -f ${GDB_FILE} ]
then
  echo "gdb download failed?"
  exit
fi
tar -xvf ${GDB_FILE}
rm ${GDB_FILE}

cd ${GDB_DIR}
./configure --target=m68k-elf --enable-lanuages=c --enable-tui=yes --prefix=$M68K_GCC_TOOLCHAIN $COMPILE_FLAGS
make -j$CORE_COUNT

if [ -f gdb/gdb ]
then
  make install
  cd $M68K_GCC_TOOLCHAIN
  rm -rf ${GDB_DIR}
  echo ""
  echo "---------------------------------------"
  echo "gdb added to m68k toolchain"
  echo "---------------------------------------"
  echo ""
else
  echo "gdb build failed? do you have libgmp, libmpfr, bison, and libncurses?"
fi