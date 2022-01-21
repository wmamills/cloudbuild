#!/bin/bash

#set -xe

SCRIPT=$(basename $0)
SCRIPT_PATH=$0
REMOTE_PATH=${2:-job/build}
REMOTE_SCRIPT_PATH=tmp-bin
ALL="conf build-log deploy task-logs sstate downloads"

first_word() {
    echo "$1"
}

make_output() {
    OE_TMP_DIR=$(first_word tmp*)
    if [ -z "$OE_TMP_DIR" -o ! -d $OE_TMP_DIR ]; then
        echo "no OE tmp-* dir, did any build happen?"
        exit 99
    fi

    while [ -n "$1" ]; do
        case "$1" in
        deploy)
            echo "making deploy archive"
            time tar caf deploy.tar.gz $OE_TMP_DIR/deploy
            ;;
        build-logs)
            echo "making build-logs archive"
            rm -rf build-logs || true
            mkdir -p build-logs/$OE_TMP_DIR
            cp *.log build-logs/
            cp -a $OE_TMP_DIR/log build-logs/$OE_TMP_DIR
            cp -a $OE_TMP_DIR/buildstats build-logs/$OE_TMP_DIR
            tar caf build-logs.tar.xz build-logs
            ;;
        conf)
            echo "making conf archive"
            tar caf conf.tar.gz conf/
            ;;
        task-logs)
            echo "making task-logs archive"
            rm -rf task-logs || true
            mkdir -p task-logs/$OE_TMP_DIR
            find $OE_TMP_DIR/work{,-shared} -type d -name temp | \
                xargs -n 1 -i bash -c "mkdir -p task-logs/{}; cp -a {}/* task-logs/{}/"
            tar caf task-logs.tar.xz task-logs
            ;;
        downloads)
            echo "making downloads archive"
            time tar caf downloads.tar --exclude="*.done" --exclude="git2" downloads/
            ;;
        sstate)
            echo "making sstate archive"
            time tar caf sstate.tar sstate-cache/
            ;;
        all)
            make_output $ALL
        esac
        shift
    done
}

get_output() {
    while [ -n "$1" ]; do
        case "$1" in
        deploy|conf)
            scp $REMOTE:$REMOTE_PATH/$1.tar.gz .
            ;;
        build-logs|task-logs)
            scp $REMOTE:$REMOTE_PATH/$1.tar.xz .
            ;;
        downloads|sstate)
            scp $REMOTE:$REMOTE_PATH/$1.tar .
            ;;
        all)
            get_output $ALL
        esac
        shift
    done
}

case "$1" in
"")
    echo "Must Supply at least a remote, such as ubuntu@192.168.42.106"
    exit 3
    ;;
on-remote)
    shift; shift || true
    cd $REMOTE_PATH
    if [ -z "$1" ]; then
        make_output all
    else
        make_output "$@"
    fi
    ;;
*)
    REMOTE=$1; shift; shift || true
    ssh $REMOTE mkdir -p $REMOTE_SCRIPT_PATH
    scp $SCRIPT_PATH $REMOTE:$REMOTE_SCRIPT_PATH/$SCRIPT
    if ! ssh $REMOTE $REMOTE_SCRIPT_PATH/$SCRIPT on-remote $REMOTE_PATH "$@"; then
        rc=$?
        echo "remote build of archives failed"
        exit $rc
    fi

    if [ -z "$1" ]; then
        get_output all
    else
        get_output "$@"
    fi
    ;;
esac
