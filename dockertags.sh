#!/usr/bin/env bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
#set -euxo pipefail
set -euo pipefail

if [ $# -lt 1 ]
then
cat << HELP

dockertags  --  list all tags for a Docker image on a remote registry.

EXAMPLE: 
    - list all tags for ubuntu:
       dockertags ubuntu

    - list all php tags containing apache:
       dockertags php apache

HELP
fi

image="$1"
tags=`wget -q https://registry.hub.docker.com/v1/repositories/${image}/tags -O -  | sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' | tr '}' '\n'  | awk -F: '{print $3}'`

if [ -n "${2:-}" ]
then
    tags=` echo "${tags}" | grep "$2" `
fi

echo "${tags}"