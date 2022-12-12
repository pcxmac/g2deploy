#!/bin/bash

# generate *.mirrors files for config, use hosts.mirrors to search through domain names, 
#   use rsync to probe for valid servers (rsync --dry-run)
#   spider through first few layers to discover potential http assets (wget)
#   crawl through first few directories to discover potential ftp assets (curl)

#   input - ../config/hosts.mirrors
#   output - ../config
#               ftp.hosts
#               http.hosts
#               rsync.hosts
#
#   derivative outputs - ../config
#   
#   releases.mirrors
#   snapshots.mirrors
#   distfiles.mirrors
#   repos.mirrors
#   
#   input - (vpn private_net search)
#   
#   outputs - ../config
#               binpkg.mirrors
#               kernel.mirrors
#               meta.mirrors
#               package.mirrors
#               patchfiles.mirrors

#   need a dom.0 locally generated directory of servers with in the PRIV_NET domain. <dom.root>