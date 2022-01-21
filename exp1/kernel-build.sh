#!/bin/bash

source common-build.sh

URL=https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.1.3.tar.xz

do_onetime() {
	echo "onetime setup" | tee msg
	do_machine_log 2>&1 | tee machine.log
	export DEBIAN_FRONTEND=noninteractive
	sudo apt update
	sudo debconf-set-selections <<EOF
debconf debconf/frontend        select  Noninteractive
debconf debconf/priority        select  critical
EOF
	# it seems above is enough but keep below handy for now
	cat <<EOF >/dev/null
libc6   libraries/restart-without-asking        boolean true
libc6:amd64     libraries/restart-without-asking        boolean true
libc6:i386      libraries/restart-without-asking        boolean true
libpam0g        libraries/restart-without-asking        boolean true
libpam0g:amd64  libraries/restart-without-asking        boolean true
libssl1.1       libraries/restart-without-asking        boolean true
libssl1.1:amd64 libraries/restart-without-asking        boolean true
EOF
	sudo apt install -y build-essential bison flex ncurses-dev libssl-dev
	if [ x"$(get_arch)" != x"aarch64" ]; then
		sudo apt install -y gcc-aarch64-linux-gnu
		aarch64-linux-gnu-gcc -v >>machine.log
	else
		gcc -v >>machine.log
	fi
	rm -rf $(basename $URL) || true
	if [ -d $(get_dirname) ]; then
		if grep -i torvalds $(get_dirname)/MAINTAINERS >/dev/null; then
			rm -rf $(get_dirname)
		else
			echo "$(get_dirname) exists but it is not a kernel"
			exit 2
		fi
	fi
	wget $URL
	tar xvf $(basename $URL)
	touch ./one-time-setup-done
}

do_config() {
	if [ ! -r ./one-time-setup-done ]; then
		do_onetime
	fi
	echo "config $1 in $(get_dirname) | tee msg"
	echo "host is $(get_arch)"
	echo "CUR_CONFIG=$1" >./.setenv
	if [ x"$(get_arch)" == x"aarch64" ]; then
		echo 'echo native compile' >>./.setenv
	else
		echo 'export ARCH=arm64' >>./.setenv
		echo 'export CROSS_COMPILE=aarch64-linux-gnu-' >>./.setenv
		echo 'echo CROSS_COMPILE=$CROSS_COMPILE'       >>./.setenv 
	fi
	. .setenv
	(cd $(get_dirname); do_cpuinfo; echo '*** distclean'; make distclean; echo "*** make $1"; make $1) 2>&1 | tee $1.log
}

do_make() {
	echo "$CUR_CONFIG: make -j $1 " | tee msg
	. .setenv
	(cd $(get_dirname); do_cpuinfo; echo "**** clean"; make clean; echo "make -j $1"; time make -j $1) 2>&1 | tee make-$CUR_CONFIG-j-$1.log
}

process_args() {
	case $i in
	*config)
		not_done
		do_config $i
		;;
	[0-9]|[0-9][0-9]|[0-9][0-9][0-9])
		not_done
		do_make $i
		;;
	*)
		false
		;;
	esac
}

process_args_common "$@"
