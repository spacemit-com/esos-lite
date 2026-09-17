#!/bin/bash

export TOP_LITE_DIR=`pwd`
export TOP_CPU_LITE_DIR="${TOP_LITE_DIR}/libcpu/risc-v/spacemit"
export TOP_BSP_LITE_DIR="${TOP_LITE_DIR}/bsp/spacemit"
export TOP_BOARD_LITE_DIR="${TOP_BSP_LITE_DIR}/platform"
export TOP_ESOS_BASE_LITE_DEFCONF="${TOP_BSP_LITE_DIR}/.esos_top.config"
export TOP_ESOS_LITE_DEFCONF="${TOP_BSP_LITE_DIR}/.config"
export TOP_ESOS_LITE_BINARY_OUTPUT="${TOP_LITE_DIR}/../../../bsp/spacemit/binary"

TARGET_CHIP_LITE=
TARGET_ENTRY_POINT_LITE=
TOP_TARGET_ENTRY_POINT_LITE=
TOP_TARGET_DEFCONFIG_LITE=

function mk_error()
{
	echo -e "\033[40;31mERROR: $*\033[0m"
}

function mk_warn()
{
	echo -e "\033[40;33;1mmWARN: $*\033[0m"
}

function mk_info()
{
	echo -e "\033[40;37mINFO: $*\033[0m"
}

# The toolchain tarballs are not carried in git anymore; pull them from the
# SpacemiT archive on demand (the same source the top-level package uses).
# $1 = destination directory, $2 = tarball name.
function fetch_toolchain()
{
	local dest="$1"
	local tarball="$2"
	local url="http://archive.spacemit.com/toolchain/${tarball}"

	mk_info "Downloading toolchain: ${url}"
	if command -v wget >/dev/null 2>&1; then
		wget -O "${dest}/${tarball}" "${url}"
	elif command -v curl >/dev/null 2>&1; then
		curl -L -o "${dest}/${tarball}" "${url}"
	else
		mk_error "Neither wget nor curl is available; cannot download ${tarball}"
		return 1
	fi
}

function select_entry_point()
{
	if [ "x${TOP_TARGET_CHIP}" = "xrt24" ]; then
 		TOP_TARGET_ENTRY_POINT_LITE=0x0
	else
		mk_error "No valid entry point!"
		return 1
	fi
}

# show target configuration
function show_target_config()
{
	echo
	mk_info "target configuration is as follows:"
	mk_info "-------------------------------------------------------------------------"
	cat ${TOP_ESOS_BASE_LITE_DEFCONF}
	mk_info "-------------------------------------------------------------------------"
}

function config_sdk()
{
	# delete the old configuration script
	rm -rf ${TOP_ESOS_LITE_DEFCONF}
	rm -rf ${TOP_ESOS_BASE_LITE_DEFCONF}

	cp ../../../bsp/spacemit/.esos_top.config ${TOP_ESOS_BASE_LITE_DEFCONF} 
	source ${TOP_ESOS_BASE_LITE_DEFCONF}

	# Skip extraction when a toolchain is already provided via RTT_EXEC_PATH;
	# otherwise fetch the tarball from the SpacemiT archive on demand.
	if [ -z "${RTT_EXEC_PATH}" ]; then
		local tc_dir="${TOP_LITE_DIR}/../../../tools/toolchain"
		local tc_tar="spacemit-toolchain-elf-newlib-x86_64-v1.0.9.tar.xz"
		mkdir -p "${tc_dir}"
		if [ "x${TOP_TARGET_CHIP}" = "xrt24" ]; then
			if [ ! -d "${tc_dir}/spacemit-toolchain-elf-newlib-x86_64-v1.0.9" ]; then
				[ -f "${tc_dir}/${tc_tar}" ] || fetch_toolchain "${tc_dir}" "${tc_tar}" || return 1
				tar -xf "${tc_dir}/${tc_tar}" -C "${tc_dir}" || { mk_error "Failed to extract ${tc_tar}"; return 1; }
			fi
		fi
	fi

	# create the rtconfig.h, it will be updated
	touch ${TOP_LITE_DIR}/bsp/spacemit/rtconfig.h
}

function build_kernel()
{
	source ${TOP_ESOS_BASE_LITE_DEFCONF}

	TOP_TARGET_DEFCONFIG_LITE=${TOP_TARGET_CHIP}_defconfig

	select_entry_point

	echo "export TOP_TARGET_ENTRY_POINT_LITE=${TOP_TARGET_ENTRY_POINT_LITE}" >> ${TOP_ESOS_BASE_LITE_DEFCONF}
	
	show_target_config

	source ${TOP_ESOS_BASE_LITE_DEFCONF}

	cp ${TOP_BOARD_LITE_DIR}/${TOP_TARGET_CHIP}/${TOP_TARGET_DEFCONFIG_LITE} ${TOP_BSP_LITE_DIR}/.config

	TARGET_CHIP_LITE=${TOP_TARGET_CHIP}
	TARGET_ENTRY_POINT_LITE=${TOP_TARGET_ENTRY_POINT_LITE}
	export TARGET_CHIP_LITE TARGET_ENTRY_POINT_LITE

	cd ${TOP_BSP_LITE_DIR}
	scons --useconfig=.config
	if [ $? -ne 0 ]; then
		mk_error "Failed to load config for ${TARGET_CHIP_LITE}"
		return -1;
	fi
	# build kernel
	scons
	if [ $? -ne 0 ]; then
		mk_error "Failed to build ${core_name}"
		return -1
	fi

	# copy the binary
	if [ ! -d "${TOP_ESOS_LITE_BINARY_OUTPUT}" ]; then
		mkdir -p ${TOP_ESOS_LITE_BINARY_OUTPUT}
	fi

	mv ${TOP_BSP_LITE_DIR}/esos_lite* ${TOP_ESOS_LITE_BINARY_OUTPUT}

	# clean the kernel
	scons -c

	return 0
}

config_sdk
build_kernel
