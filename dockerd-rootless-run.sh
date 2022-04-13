#!/usr/bin/env bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
#set -euxo pipefail
set -euo pipefail

# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
# set -euxo pipefail

# Automatic Nodejs isolation script using docker (or rootless docker)

# this is the bin that we are trying to run from link
BINPATH="$HOME/bin"
mkdir -p "$BINPATH"
BINPATH_MAIN="$(dirname "$(realpath "$0")")"
RUNBIN="$(basename $0)"
# this is the main script name
MAINSCRIPT="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
MAINSCRIPT_PATH="$BINPATH_MAIN/$MAINSCRIPT"


##########################
### RUNTIME CODE BELOW ###
##########################

linkItPre(){
        BIN_NAME=$1
        local -n BIN_BINS=$2
        local -n BIN_TAGS=$3
        local -n BIN_MODES=$4

        for BIN_BINS_I in ${!BIN_BINS[@]}; do
                BIN_BIN=${BIN_BINS[$BIN_BINS_I]}

                for BIN_TAG_I in ${!BIN_TAGS[@]}; do
                        BIN_TAG=${BIN_TAGS[$BIN_TAG_I]}

                        for BIN_MODE_I in ${!BIN_MODES[@]}; do
                                BIN_MODE=${BIN_MODES[$BIN_MODE_I]}

                                out="$BIN_BIN"
                                [ -z "${BIN_TAG:-}" ] || out+=":$BIN_TAG"
                                [ -z "${BIN_MODE:-}" ] || out+="-$BIN_MODE"
                                linkIt "$out"
                        done
                done
        done
}
BIN_TAGS_ALL=( "" "latest" )
BIN_MODES_ALL=( "" "rw" "ro" )

BINS_NODE_BINS=( "node" "npm" "npx" )
BINS_NODE_TAGS=( "" "16" "latest" )

BINS_MOSQUITTO=( "mosquitto" "mosquitto_pub" "mosquitto_sub" "mosquitto_rr" "mosquitto-tls" "mosquitto_passwd" "mosquitto_ctrl" )

makeLinks(){
        linkItPre "node" BINS_NODE_BINS BINS_NODE_TAGS BIN_MODES_ALL
        linkItPre "eclipse-mosquitto" BINS_MOSQUITTO BIN_TAGS_ALL BIN_MODES_ALL
}

if [[ "$RUNBIN" == "$MAINSCRIPT" ]]; then
        echo Running install mode

        linkIt(){
                echo "Linking $MAINSCRIPT -> $BINPATH/$1" 
                [ -f "$BINPATH/$1" ] || ln -s "$MAINSCRIPT_PATH" "$BINPATH/$1"
        }

        makeLinks

        # Install rootless docker if there is no docker installed
        # https://docs.docker.com/engine/security/rootless/
        if [ ! -x "`command -v docker`" ]; then
                echo "$MAINSCRIPT: docker not installed.... now installing as rootless..."

                sudo apt-get update

                        # Found that ubuntu no longer ships with curl but it has wget!
                bash <(wget -O - -o /dev/null https://get.docker.com)

                # https://docs.docker.com/engine/security/rootless/
                sudo apt-get install -y uidmap
                sudo apt-get install -y dbus-user-session
                
                # fuse-overlayfs is a requiremnt per limitations: https://docs.docker.com/engine/security/rootless/
                sudo apt-get install -y fuse-overlayfs

                dockerd-rootless-setuptool.sh install
                sudo systemctl disable --now docker.service docker.socket
                
                sudo setcap cap_net_bind_service=ep /usr/bin/rootlesskit
                echo net.ipv4.ip_unprivileged_port_start=0 | sudo tee --append "/etc/sysctl.conf"
                sudo sysctl --system
        fi

        echo Done!
elif false ; then
        # default access (ro)
        BINNAME_MODE="ro"
        BIN_TAG=""
        if [[ $RUNBIN =~ ([^:]*)(:[^-]*)-(rw|ro)$ ]] \
                || [[ $RUNBIN =~ ([^:]*)(:[^-]*)()$ ]] \
                || [[ $RUNBIN =~ ([^:]*)()-([^-]*)$ ]] \
                || [[ $RUNBIN =~ ([^:]*)()()$ ]]
        then
                BIN_NAME="${BASH_REMATCH[1]}"
                BIN_TAG="${BASH_REMATCH[2]}"
                BINNAME_MODE="${BASH_REMATCH[3]}"
                RUNNAME="::::::"

                # echo "${BASH_REMATCH[0]} RUNBIN: $RUNBIN BIN_TAG: $BIN_TAG BINNAME_MODE: $BINNAME_MODE"


                #docker container list
                #docker image list
                # --name my-running-script
                
        else
                echo "Cannot parse command"
        fi
else
        ARGS=( "$@" )
        linkIt(){
                if [[ "$1" == "$RUNBIN" ]]; then
                        [ ! -x "`command -v dockerd-rootless-setuptool.sh`" ] \
                                || [ -n "${DOCKER_HOST:=""}" ] \
                                || export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
                        
                        BIN_NAME="${BIN_NAME}:${BIN_TAG:=latest}"

                        DOCKER_FLAGS=${DOCKER_FLAGS:=}
                        docker run -it --rm $DOCKER_FLAGS -v "$PWD:/usr/src/app:${BIN_MODE:=ro}" -w /usr/src/app "${BIN_NAME}" "${BIN_BIN}" "${ARGS[@]}"
                        exit
                fi
        }
        makeLinks
        
        echo "Cannot parse command"
fi