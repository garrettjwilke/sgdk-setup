# compile SGDK for MacOS
this will compile the gcc tools for the motorolla 68000 and also the SGDK tools and libraries. the result will be macOS arm64 native toolkit to compile SGDK projects. the advantage to this is compile time speed.

i have created a script to do all of this automatically. scroll to the bottom to see instructions to use the script. the individual instructions are here simply for reference and if my script breaks, at least there is some sort of documentation about what it is trying to do.

### requirements before starting
* [brew](https://brew.sh/) 

once brew is installed, you will need the following packages:

* [git](https://formulae.brew.sh/formula/git)
* [wget](https://formulae.brew.sh/formula/wget)
* [texinfo](https://formulae.brew.sh/formula/texinfo)
* [gcc-13](https://formulae.brew.sh/formula/gcc)
* [openjdk](https://formulae.brew.sh/formula/openjdk)

```
brew install git wget texinfo gcc@13 openjdk
```

after installing these packages, the system might not set the `PATH` immediately, so it is best to close the current terminal and re-open a new terminal.

## compiling the toolchain

when you use SGDK on windows, the toolchain and libraries are already compiled, thus the toolchain is self contained and not installed on a system level (you can delete the SGDK directory in windows and nothing breaks). in this tutorial, we will be installing the gcc-m68k toolchain in the `home` directory. this allows us to simply delete the SGDK directory if we don't need it anymore and nothing breaks. on my system, i have a `build` directory inside of my `home` directory, but you can name this directory whatever you want:

```
mkdir ~/build
cd ~/build
```

### compile gcc for m68k
you will need gcc compiled for the motorolla 68000 target. this part of the process takes the longest. in order to keep this clean, we will separate the compiled output and the raw source folders;

```
mkdir -p m68k-gcc-toolchain/{src,build}
```

you should now have a `m68k-gcc-toolchain` directory. let's `cd` into the `src` directory and download the gcc tool sources. we will need the following:

* binutils
* gcc

there are many mirrors to download the source, for this we will use the UC Berkeley servers:

```
cd m68k-gcc-toolchain/src
wget https://mirrors.ocf.berkeley.edu/gnu/binutils/binutils-2.44.tar.gz
wget https://mirrors.ocf.berkeley.edu/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.gz
```

after downloading the source, we need to extract them. after they are extracted, you can delete the `.tar.gz` files for each:

```
tar -xzf binutils-2.44.tar.gz
tar -xzf gcc-14.2.0.tar.gz
rm binutils-2.44.tar.gz gcc-14.2.0.tar.gz
```

we now can `cd` into the `gcc-14.2.0` directory and download the prerequisites:

```
cd gcc-14.2.0
./contrib/download_prerequisites
```

after the prereqs are finished downloading, create a directory for the `binutils` build and `cd` into it:

```
mkdir ~/build/m68k-gcc-toolchain/build/binutils-2.44
cd ~/build/m68k-gcc-toolchain/build/binutils-2.44
```

we need to set up so the compiler flags are correctly set. the target will be in the `~/build/m68k-gcc-toolchain` directory, so that when we run `make install` it will install there rather than system wide:

```
export CC=gcc-13
export CXX=g++-13

~/build/m68k-gcc-toolchain/src/binutils-2.44/configure \
  --target=m68k-elf \
  --prefix=$HOME/build/m68k-gcc-toolchain \
  --disable-nls --disable-werror \
  --without-headers --without-newlib

make -j8
make install
```

after this finishes, we will do the same for the `gcc` toolchain. this process takes a while to compile:

```
mkdir ~/build/m68k-gcc-toolchain/build/gcc-14.2.0
cd ~/build/m68k-gcc-toolchain/build/gcc-14.2.0

~/build/m68k-gcc-toolchain/src/gcc-14.2.0/configure \
  --target=m68k-elf \
  --prefix=$HOME/build/m68k-gcc-toolchain \
  --enable-languages=c --without-headers --without-newlib \
  --disable-shared --disable-libstdcxx --disable-threads \
  --disable-libssp --disable-libgomp --disable-libquadmath \
  --disable-libmudflap --disable-nls \
  --with-cpu=68000

make -j8 all-gcc
make -j8 all-target-libgcc
make install-gcc
make install-target-libgcc
```

if everything worked, we now have the gcc toolchain ready to go. compiling from source uses up a lot of disk space, so you can now remove the old `src` and `build` directories if you want:

```
cd ~/build/m68k-gcc-toolchain
rm -rf build
rm -rf src
```

the gcc toolchain for m68k is now compiled and we can move on to building SGDK tools natively for arm64 macOS.

### compiling SGDK tools for arm64 mac

now that we have the m68k gcc tools, we need to clone the latest SGDK and build the tools and libraries for it. `sjasm` is required to build so we will build `sjasm` and put the binary into the `SGDK/bin` directory:

```
cd ~/build
git clone https://github.com/Stephane-D/SGDK.git
git clone https://github.com/Konamiman/Sjasm
cd Sjasm
git checkout v0.39
cd Sjasm
export CXX=/usr/bin/g++
export CC=/usr/bin/gcc
make sjasm -j8
cp sjasm ~/build/SGDK/bin/
```

we now need to build the tools that SGDK uses to compile your rom.

the first tool we compile is `xgmtool` for the XGM sound driver in SGDK:

```
cd ~/build/SGDK/tools/xgmtool
gcc src/*.c -Wall -O2 -lm -o xgmtool
strip xgmtool
mv xgmtool ~/build/SGDK/bin/
```

the next tool is `bintos`:

```
cd ~/build/SGDK/tools/bintos
gcc src/bintos.c -Wall -O2 -o bintos
strip bintos
mv bintos ~/build/SGDK/bin/
```

and the last tool we need to compile for SGDK is `convsym`:

```
cd ~/build/SGDK/tools/convsym
make -j8
mv build/convsym ~/build/SGDK/bin/
```

after building the SGDK tools, the last step is to build the libraries: we need to add our newly compiled `m68k-elf-gcc` tools to our `PATH` so the system knows where to find our tools. you can temporarily add to `PATH` like this:

```
export PATH=~/build/SGDK/bin:$PATH
export PATH=~/build/m68k-gcc-toolchain/bin:$PATH
```

once you close your terminal, the `PATH` will be reset, so it is best to add the 2 lines above to your `.zshrc`. run these commands, to add to `PATH` and re-source your environment variables:

```
echo -n 'export PATH=$HOME/SGDK/bin:$PATH' >> ~/.zshrc
echo "" >> ~/.zshrc
echo -n 'export PATH=$HOME/m68k-gcc-toolchain/bin:$PATH' >> ~/.zshrc
source ~/.zshrc
```

the final step is to build the SGDK libraries for the `release` and `debug` builds:

```
cd ~/build/SGDK
make -f makelib.gen clean-release
make -f makelib.gen release
make -f makelib.gen clean-debug
make -f makelib.gen debug
```

## how to use

now that we have built our toolchain, the SGDK tools, and the SGDK libraries, we can build SGDK roms now using native tools! we can test this by attempting to compile the `SGDK/sample/basics/hello-world` code:

```
cd ~/build/SGDK/sample/basics/hello-world
make -f ~/build/SGDK/makefile.gen release
```

the above example compiled the `release` version of the rom. the compiled rom will be in `out/release/rom.bin`.

you can compile the debug version with symbols like this:

```
cd ~/build/SGDK/sample/basics/hello-world
make -f ~/build/SGDK/makefile.gen debug
```

## install script

```
git clone https://github.com/garrettjwilke/sgdk-setup.git
cd sgdk-setup
```

this script will run the same commands as the tutorial above, but it is automated. it is split into 2 separate scripts to split the process for building the `gcc` toolchain and the `SGDK` tools/lib.

* `m68k-setup.sh`
* `sgdk-setup.sh`

both of these scripts are dynamic and the version numbers and mirrors can be adjusted by editing the `tool-variables` file. the gcc version number and binutils version numbers can be adjusted in this file.

### m68k gcc script
before installing the SGDK stuff, we first need to build the `gcc` toolchain:

```
./m68k-setup.sh
```

after running the script above, you will have the `gcc` toolchain installed to:

`~/build/m68k-gcc-toolchain`

you will need to add to `PATH` manually, as this is intended to not disturb your configs:

```
echo -n 'export PATH=$HOME/m68k-gcc-toolchain/bin:$PATH' >> ~/.zshrc
source ~/.zshrc
```

### SGDK tools/lib setup

after installing the `gcc` toolchain, you can then install the `SGDK` tools and libraries:

```
./sgdk-setup.sh
```

you will need to add to `PATH` manually, as this is intended to not disturb your configs:

```
echo -n 'export PATH=$HOME/m68k-gcc-toolchain/bin:$PATH' >> ~/.zshrc
source ~/.zshrc
```

you can then build any SGDK project. see the "how to use" section above.
