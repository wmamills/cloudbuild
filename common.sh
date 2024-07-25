# Useful functions for multiple scripts in this family
# This file needs to be sourced

abort() {
    echo "Error: $@"
    exit 2
}

exit_ok() {
    echo "$@"
    exit 0
}

first_word() {
    echo $1
}

# add a local rule to ignore things in .prjinfo/local
# this should keep the status output clean
# However any other items in ./prjinfo will show in the status
add_local_gitignore() {
    # skip this if this dir is not under git control
    if [ -d .git/info ]; then
        # is it already there?
        if [ ! -f .git/info/exclude ] || \
            ! grep -q '/.prjinfo/local' .git/info/exclude; then
            # add the ignore rule
            echo "/.prjinfo/local" >>.git/info/exclude
        fi
    fi
}

local_config() {
    # allow user to override default settings
    # normally settings should use
    #   : ${VAR:=value}
    # in which case the first one processed wins
    # ENV vars, project local, the project checked in, the global user
    # use of
    #   VAR=value
    # means an override, last one processed wins
    # High to low: global user, project checked in, project local, env vars
    for d in .prjinfo/local .prjinfo  ~/.prjinfo ; do
        if [ -r $d/setenv ]; then
            . $d/setenv
        fi
    done

    set_defaults
}

get_distro_type() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        cat /etc/os-release
        TYPE=${ID_LIKE:-$ID}
        TYPE=$(first_word $TYPE)
        VERSION_MAJOR=${VERSION_ID%%.*}
        echo distro type is $TYPE
    else
        TYPE="unknown"
        VERSION_MAJOR=0
    fi
}

# add sudo package to machine, needs to run as root
add_sudo() {
    # do we already have it?
    if which sudo >/dev/null 2>&1; then
        return
    fi

    case "$TYPE" in
    debian)
        apt update
        apt install -y sudo
        ;;
    fedora)
        dnf install -y sudo
        ;;
    rhel)
        yum install -y sudo
        ;;
    *)
        echo "don't know how to install sudo for distro type: $TYPE"
        exit 127
        ;;
    esac
}

# do setup for user, needs to run as root
setup_distro() {
    get_distro_type
    if id $MY_UID; then
        OLD_USER=$(id -nu $MY_UID)
        echo "Removing user $OLD_USER, as it conflicts with user $MY_USER $MY_UID:$MY_GID"
        userdel $OLD_USER
    fi
    groupadd --gid $MY_GID $MY_USER
    useradd  --uid $MY_UID --gid $MY_GID --shell /bin/bash -mN $MY_USER

    # handle sudo options
    case $OPT_SUDO in
    yes)
        add_sudo
        groupadd --system sudo_np
        usermod -a -G sudo_np $MY_USER
        mkdir -p /etc/sudoers.d/
        echo "%sudo_np ALL=(ALL:ALL) NOPASSWD:ALL" >/etc/sudoers.d/sudo_np
        ;;
    pwd)
        add_sudo;
        adduser $MY_USER sudo
        ;;
    no)
        true
        ;;
    *)
        "echo bad value for OPT_SUDO: $OPT_SUDO"
        exit 127
        ;;
    esac

    export DEBIAN_FRONTEND=noninteractive
}

get_common_options() {
    DISTRO="ubuntu:20.04"
    PRJ_SCRIPT="scripts/setup.sh"
    OPT_SUDO=yes

    SHIFT_COUNT=0
    while true; do
        case "$1" in
        --distro)
            DISTRO=$2
            shift 2
            SHIFT_COUNT=$(( $SHIFT_COUNT + 2 ))
            ;;
        --script)
            PRJ_SCRIPT=$2
            shift 2
            SHIFT_COUNT=$(( $SHIFT_COUNT + 2 ))
            ;;
        --sudo)
            case "$2" in
            yes|YES)
                OPT_SUDO=yes
                ;;
            no|NO)
                OPT_SUDO=no
                ;;
            pwd|PWD)
                OPT_SUDO=pwd
                ;;
            *)
                echo "unknown option for --sudo given: $2"
                exit 2
            esac
            shift 2
            SHIFT_COUNT=$(( $SHIFT_COUNT + 2 ))
            ;;
        --*)
            echo unknown option "$1"
            exit 2
            ;;
        *)
            return
            ;;
        esac
    done
}
