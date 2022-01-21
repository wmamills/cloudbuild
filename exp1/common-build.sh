# this file needs to be sourced not run

set -e

get_arch() {
	echo "$(uname -m)"
}

get_dirname() {
	local file
	file=$(basename $URL)
	echo "${file%%.tar*}"
}

do_cpuinfo() {
	echo "*** cpuinfo"
	echo "Host is $(get_arch)"
	grep -i Bogo /proc/cpuinfo || true
	grep "model name" /proc/cpuinfo || true
}

do_machine_log() {
	echo "*** lsb_release -a"
	lsb_release -a
	echo "**** uname -a"
	uname -a
	echo "**** cpuinfo"
	cat /proc/cpuinfo
	echo "**** free -h"
	free -h
	echo "**** lsblk"
	lsblk
	echo "**** dh -h"
	df -h
}

do_shutdown() {
	echo "*** will shutdown in 10 min" | tee msg
	sleep 600
	sudo shutdown +10
}

do_done() {
	echo "ALL DONE!" | tee msg | tee all-done
}

do_watch() {
	watch bash -c 'echo "***"; ls -l; grep -i ^real *.log'
}

not_done() {
	DID_WORK=true
	rm -rf ./all-done >/dev/null 2>&1
}

process_args_common() {
DID_WORK=false

for i in $@; do

    if process_args "$@"; then
        continue;
    fi

	case $i in
	onetime)
		not_done
		do_onetime
		;;
	shutdown)
		not_done
		do_shutdown
		;;
	done)
		DID_WORK=false		# won't need it at the end unless we do more work
		do_done
		;;

	# the commands below do no real "work" and don't create the done marker
	start_screen)
		shift
		echo "starting test run in screen job" | tee msg
		screen -d -m -S BUILD ./kernel-build.sh "$@"
		screen -ls
		sleep 10
		exit 0
		;;
	watch)
		do_watch
		;;
	build-status)
		cat msg 2>/dev/null
		if [ -r all-done ]; then
			exit 0
		else
			exit 2
		fi
		;;
	*)
		echo bad argument $i
		;;
	esac
done

if $DID_WORK; then
	do_done
fi
}
