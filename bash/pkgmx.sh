#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

#   USE: (commands via args) 
#
#       prune : prune binpkgs/Packages
#       
#       build=*PACKAGE*
#       build=*CLASS*
#       build=ALL
#       
#       use=TARGETED | MAP | ALL
#       
#       clean : remove stale distfiles | releases | snapshots | binpkgs
#       
#       build_db : map all resources and dependencies for all packages, given a specific REPO commit 
#
#       *notes : no sophisticated relational operations will occur w/ this script, this script is for scraping and compiling
#                and basic processing.

