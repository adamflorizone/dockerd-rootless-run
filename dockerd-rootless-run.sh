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

default-mosquitto-config() {
        cat <<- EOF
        listener 1883
        allow_anonymous true

        listener 9001
        protocol websockets
        allow_anonymous true
EOF
}

corretIt(){
        if [[ "$BIN_NAME" == eclipse-mosquitto+(:*|) ]]; then
                # Per: https://github.com/eclipse/mosquitto/blob/8212bbe29b6fc0a49c30a15b22a36ff0ac7b9d32/docker/2.0/Dockerfile

                if [ "$BIN_BIN" == "mosquitto" ]; then
                        ARGS+=( "-c" "/mosquitto/config/mosquitto.conf" )

                        tmppipe=$(mktemp)
                        default-mosquitto-config > "$tmppipe"
                        
                        DOCKER_FLAGS_EXTRAS+=( --publish 1883:1883 --publish 9001:9001 --volume "$tmppipe:/mosquitto/config/mosquitto.conf:ro" )
                fi

                if [[ "$BIN_BIN" =~ ^(mosquitto_sub|mosquitto_pub)$ ]]; then
                        [ ! -f "$HOME/.config/mosquitto_sub" ] || DOCKER_FLAGS_EXTRAS+=( --volume "$HOME/.config/mosquitto_sub:/root/.config/mosquitto_sub:ro" )
                        [ ! -f "$HOME/.config/mosquitto_pub" ] || DOCKER_FLAGS_EXTRAS+=( --volume "$HOME/.config/mosquitto_pub:/root/.config/mosquitto_pub:ro" )
                
                        DOCKER_FLAGS_EXTRAS+=( --network="host" )
                fi
        fi
}

makeLinks(){
        BINS_VOLUME_PWD=true linkItPre "node" BINS_NODE_BINS BINS_NODE_TAGS BIN_MODES_ALL
        BINS_VOLUME_PWD=false linkItPre "eclipse-mosquitto" BINS_MOSQUITTO BIN_TAGS_ALL BIN_MODES_ALL

        rm "$tmppipe"
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
                        DOCKER_FLAGS_EXTRAS=( ${DOCKER_FLAGS:=} )
                        
                        [ ! -x "`command -v dockerd-rootless-setuptool.sh`" ] \
                                || [ -n "${DOCKER_HOST:=""}" ] \
                                || export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
                        
                        BIN_NAME="${BIN_NAME}:${BIN_TAG:=latest}"

                        corretIt

                        if [ "$BINS_VOLUME_PWD" = true ]; then
                                DOCKER_FLAGS_EXTRAS+=( -w /usr/src/app --volume "$PWD:/usr/src/app:${BIN_MODE:=ro}" )
                        fi

                        # Cant pipe with -it
                        docker run -i --rm "${DOCKER_FLAGS_EXTRAS[@]}" "${BIN_NAME}" "${BIN_BIN}" "${ARGS[@]}"
                        
                        exit
                fi
        }
        makeLinks
        
        echo "Cannot parse command"
fi