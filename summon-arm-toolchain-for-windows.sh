#!/bin/bash
# Written by Uwe Hermann <uwe@hermann-uwe.de>, released as public domain.
# Modified by Piotr Esden-Tempski <piotr@esden.net>, released as public domain.
# Modified by Mikhail Avkhimenia <mikhail@avkhimenia.com>, released as public domain.

##############################################################################
# THERE IS A BETTER REPLACEMENT FOR THIS!
##############################################################################

# GNU Tools for ARM Embedded Processors is a reliable and well-tested toolchain
# available in both source and binaries. It can be downloaded here:
# https://launchpad.net/gcc-arm-embedded

# Also, you can download the pre-built binaries of SAT for Windows here:
# http://dl.bintray.com/content/clouded/Summon-ARM-Toolchain-for-Windows

# Compilation of the Summon ARM Toolchain for Windows may be less painfull if
# it is done through cross-compilation by MinGW on Linux since it's a way to
# avoid a lot of msys problems such as freezes on parallel make jobs, heap 
# problems and lack of tools. 

##############################################################################
# Requirements (for Windows)
##############################################################################

# MinGW - tested version is x32-4.8.0-release-posix-sjlj-rev0 downloaded from
# http://sourceforge.net/projects/mingwbuilds/files/host-windows/releases/4.8.0

# MSYS - tested version 1.0.11 from 
# http://sourceforge.net/projects/mingw/files/MSYS/Base/msys-core/msys-1.0.11/

# GMP/MPFR/MPC - tested gmp-5.1.1, mpfr-3.1.2, mpfr-2.4.1 built from source.
# Binary versions from http://sourceforge.net/projects/mingw/files/MinGW/Base/
# also seem to be fine, if you want to use them you need dll and dev packages.
# Place dlls in mingw32\bin and unpack dev packages in mingw32\i686-w64-mingw32

# Sources for binutils, gcc, newlib-nano (or newlib) and gdb.
# Download\clone\unpack sections have been removed from the script since 
# msys is lacking a lot of tools and downloading and installing them would
# take the same time as to manually download and unpack needed sources.
# So simply download and unpack into the working directory (i.e. /c/dev):
# http://ftp.gnu.org/gnu/binutils/binutils-2.23.1.tar.bz2
# http://ftp.gnu.org/gnu/gcc/gcc-4.8.0/gcc-4.8.0.tar.gz
# https://github.com/32bitmicro/newlib-nano-1.0/archive/master.zip
# http://ftp.gnu.org/gnu/gdb/gdb-7.5.1.tar.bz2

##############################################################################
# Possible problems and workarounds
##############################################################################

#1
# In case make cannot find gmp\mprf\mpc or if you encounter an error that says
# "Cannot compute suffix" try these options:
#
#GCCFLAGS="${GCCFLAGS} --with-gmp=${MINGW_PATH} --with-mpfr=${MINGW_PATH} \ 
#--with-mpc=${MINGW_PATH} --with-libiconv-prefix=${MINGW_PATH}"
#
# You may also try to set paths to dynamic libraries:
#
#export LD_INCLUDE_PATH=$LD_INCLUDE_PATH:${MINGW_PATH}/include
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${MINGW_PATH}/lib

#2
# If you get "couldn't commit memory for cygwin heap" error you can try to:
# Simply re-run the script and since some of the things are already built the
# process will require less memory.
# Disable all antivirus and firewall software.
# Disable\close\stop as much services and programs as possible.
# Download msys of another version.
# Rebase msys-1.0.dll \ rebase all.

##############################################################################
# Stop if any command fails
set -e 

##############################################################################
# Default settings section
# You probably want to customize those
##############################################################################

TARGET=arm-none-eabi		# Or: TARGET=arm-elf
PREFIX=/c/dev/sat	        # Install location of your final toolchain
MINGW_PATH=/c/dev/mingw32	# Location of mingw
DEFAULT_TO_CORTEX_M3=0		# Make the gcc default to Cortex-M3
export ABI=32 				# =32 if you're using mingw32 on 64-bit windows

##############################################################################
# Version section
##############################################################################

BINUTILS=binutils-2.23.1
GCC=gcc-4.8.0
NEWLIB=newlib-nano-1.0-master
GDB=gdb-7.5.1

##############################################################################
# Flags section
##############################################################################

MAKEFLAGS=-j1 #make freezes on big builds if you set more than 1 job

STAMPS=$(pwd)/stamps
SOURCES=$(pwd)/sources

##############################################################################
# Building section
# You probably don't have to touch anything after this
##############################################################################

function log {
    echo "******************************************************************"
    echo "* $*"
    echo "******************************************************************"
}

# Setting up the 'clean' path, so Windows programs don't interfere
export PATH="${PREFIX}/bin:${MINGW_PATH}/bin:/bin:/usr/bin:/usr/local/bin"

mkdir -p ${STAMPS}
mkdir -p build

# Configuring and building binutils
if [ ! -e ${STAMPS}/${BINUTILS}.build ]; then	
	cd ${BINUTILS}
	if [ ! -e include/opcode/arm.h.orig ]; then
		log "Patching binutils to allow SVC support on cortex-m3"
		patch -p0 -i ../patches/patch-binutils-2.23.1-svc-cortexm3.diff
	fi	
	cd ..
	cd build
	log "Configuring ${BINUTILS}"
    ../${BINUTILS}/configure --target=${TARGET} \
							--prefix=${PREFIX} \
							--enable-multilib \
							--with-gnu-as \
							--with-gnu-ld \
							--disable-nls \
							--disable-werror \
							${BINUTILFLAGS}
	log "Building ${BINUTILS}"
	make ${MAKEFLAGS}
	make install
	cd ..
	log "Cleaning up ${BINUTILS}"
	touch ${STAMPS}/${BINUTILS}.build
	rm -rf build/* ${BINUTILS}
fi


# Making gcc-newlib junctions
if [ ! -e gcc-4.8.0/newlib ]; then
	log "Adding newlib directory junction to gcc"
	/c/Windows/System32/cmd.exe //c "mklink /J ${GCC}\newlib ${NEWLIB}\newlib"
fi	

if [ ! -e gcc-4.8.0/libgloss ]; then
	log "Adding libgloss directory junction to gcc"
	/c/Windows/System32/cmd.exe //c "mklink /J ${GCC}\libgloss ${NEWLIB}\libgloss"
fi


# Patching GCC
cd ${GCC}

if [ ${DEFAULT_TO_CORTEX_M3} == 0 ] ; then		
	if [ ! -e gcc/config/arm/t-arm-elf.orig ]; then
		log "Patching gcc to add multilib support"
		patch -b -p0 -i ../patches/patch-gcc-config-arm-t-arm-elf.diff
	fi
	if [ ! -e libgcc/Makefile.in.orig ]; then
		log "Patching libgcc to add multilib support"
		patch -b -p0 -i ../patches/patch-${GCC}-libgcc-divide-exceptions.diff
	fi			
fi

if [ ! -e gcc/configure.orig ]; then
	log "Patching gcc to fix define caddr_t char * error"
	patch -b -p0 -i ../patches/patch-gcc-4.8.0-cofigure.diff
fi

cd ..
	
# Configuring GCC and newlib	
cd build
	
if [ ! -e ${STAMPS}/${GCC}-${NEWLIB}.configure ]; then	
	log "Configuring ${GCC} and ${NEWLIB}"
	../${GCC}/configure --target=${TARGET} \
						--prefix=${PREFIX} \
						--enable-multilib \
						--enable-languages="c,c++" \
						--with-newlib \
						--with-gnu-as \
						--with-gnu-ld \
						--disable-nls \
						--disable-shared \
						--disable-threads \
						--with-headers=newlib/libc/include \
						--disable-libssp \
						--disable-libstdcxx-pch \
						--disable-libmudflap \
						--disable-libgomp \
						--disable-werror \
						--with-system-zlib \
						--disable-newlib-supplied-syscalls \
						${GCCFLAGS}
	touch ${STAMPS}/${GCC}-${NEWLIB}.configure
fi
		
# Building GCC and newlib		
if [ ! -e ${STAMPS}/${GCC}-${NEWLIB}.build ]; then	
	log "Building ${GCC} and ${NEWLIB}"
	make ${MAKEFLAGS}
	make install
	cd ..
	log "Cleaning up ${GCC} and ${NEWLIB}"
	touch ${STAMPS}/${GCC}-${NEWLIB}.build
	rm -rf build/* ${GCC} ${NEWLIB}
fi

# Configuring and building GDB
if [ ! -e ${STAMPS}/${GDB}.build ]; then
	cd build
	log "Configuring ${GDB}"
	../${GDB}/configure --target=${TARGET} \
						--prefix=${PREFIX} \
						--enable-multilib \
						--disable-werror \
						${GDBFLAGS}
	log "Building ${GDB}"
	make ${MAKEFLAGS}
	make install
	cd ..
	log "Cleaning up ${GDB}"
	touch ${STAMPS}/${GDB}.build
	rm -rf build/* ${GDB}
fi