### GOALS:
###### - Create a Gentoo installation which is completely independent of a 'meta-server'
###### - Create a (modular) 'panel' for package and installation management across any network
###### - Create a reliable repository for sharing gentoo related files
###### - Create a reliable build service for testing package combinations

### Version/Feature Targets:
###### - 0.X <span style="color:red">Currently in pre-release</span>
###### - 0.1 Stable installs, updates and deployments w/ ZFS 
###### - 0.2 Stable installs, updates and deployments w/ ZFS;BTRFS;XFS;EXT4
###### - 0.3 Method for integrating 'g2deploy' in to a new environment (installer)
###### - 0.4 Meta Package Manager w/ package repo (git based)
###### - 0.5 Profiling for updates/installs
###### - 0.6 Patch-Fixes + signed binary packages
###### - 0.7 Multi-Arch
###### - 0.8 Panel Integration
###### - 0.9 Beta / Stable (30 Days) + Panel Fixes




#### <u>HOW TO USE: (PRE-RELEASE < v0.1) | { v1.x = last stand alone implementation } | ZFS >primary target< </u>
##### <u>SIMPLE LOCAL DEPLOYMENT ... LOCAL ONLY.</u>
  <u>./deploy.sh</u> <b>build=plasma work=zpool/plasma deploy</b>
  
###
##### <u>UPDATE USR SPACE FOR POOL/SET</u>

  <u>./update.sh</u> <b>work=pool/set bootpart=/dev/sdX# update</b><span style="color:green"> (update /boot...loader + runtime (ie kernel upgrade))</span>

  <u>./update.sh</u> <b>work=pool/set update</b><span style="color:green"> (only update runtime)</span>

  <u>./update.sh</u> <b>work=/ update</b><span style="color:green"> (update root system)</span>

###
##### <u>NEW DISK + LOCAL OR REMOTE SOURCE</u>

  <u>./install.sh</u> <b>work=zfs://wSys/hardened@safe boot=zfs:///dev/sda:/usb/g1 init</b><span style="color:green">(standard installation)</span>

  <u>./install.sh</u> <b>work=zfs://root@10.1.0.1:/wSys/gnome@safe boot=zfs:///dev/nvme0n1:/saturn/g2 init</b><span style="color:green">(remote source ZFS Send/Recv --ssh) </span>
  
  <u>./install.sh</u> <b>work=zfs://root@localhost:/test/hardened@safe boot=zfs://saturn/g2 add</b> <span style="color:green">(add to existing pool, only add boot record</span> <span style="color:red"></span>

  <u>./install.sh</u> <b>work=zfs://root@localhost:/test/hardened@safe add=zfs:///dev/sdj:/saturn/g2 config</b> <span style="color:green">(only show yaml config)</span> <span style="color:red"></span>

###
##### <u>MIRROR URL FOR TYPE OF RESOURCE + PROTOCOL </u>

  <u>./mirror.sh</u> <b>../config/mirrors/patchfiles rsync</b>\
  <span style="color:blue">ex. output => "rsync://pkg.hypokrites.me/gentoo/patchfiles" (URI for patchfiles rsync access) </span>

  <u>./mirror.sh</u> <b>../config/mirrors/releases rsync</b>\
  <span style="color:blue">rsync://mirror.csclub.uwaterloo.ca/gentoo-distfiles/releases/</span>

  <u>./mirror.sh</u> <b>../config/mirrors/releases http plasma</b> <span style="color:red"> (releases mirror can accept a 'profile' argument, all others are type and protocol)</span>\
  <span style="color:blue">http://pkg.hypokrites.me/gentoo/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/stage3-amd64-desktop-openrc-20221205T133149Z.tar.xz</span> \
  <span style="color:blue">http://pkg.hypokrites.me/gentoo/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/stage3-amd64-desktop-openrc-20221205T133149Z.tar.xz.asc</span>

  <u>./mirror.sh</u> <b>../config/mirrors/releases rsync hardened</b>\
  <span style="color:blue">rsync://mirrors.rit.edu/gentoo/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-20221225T170313Z.tar.xz</span> \
  <span style="color:blue">rsync://mirrors.rit.edu/gentoo/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-20221225T170313Z.tar.xz.asc</span>

  <u>./mirror.sh</u> <b>../config/mirrors/kernel ftp</b>\
  <span style="color:blue">ftp://pkg.hypokrites.me/kernels/current/</span>


<u>./mirror.sh</u> <b>../config/mirrors/package http</b>\
<span style="color:blue">http://pkg.hypokrites.me/gentoo/packages</span>

<u>./mirror.sh</u> <b>../config/mirrors/distfiles rsync</b>\
<span style="color:blue">rsync://mirror.csclub.uwaterloo.ca/gentoo-distfiles/distfiles</span>
####
<span style="color:red"><b>*</b> : </span> which servers are enabled/disabled (commented out), are controlled by the *.mirrors files in ../config

  ###
  ##### <u>SYNCHRONIZE BACKEND</u>

  <u>./esync.sh</u>            # checkout backend spec/folder specification, this script populates about half of the /var/lib/portage directory, but about 99% of the data. 

###
###  [ BACKEND SPEC. ]
  {host.cfg::pkgServer.root} 
```
  ├── binpkgs                   locally built, on build server, or built through sshfs, can be clone, (and snapshotted to preserve 'versioning' ?)
  ├── kernels                   kernel repo for distribution, *current, and *depreciated
  |-----------                  X.Y.Z-gentoo (ex. /6.0.1-gentoo)
  |-------------------          modules.tar.gz (from /lib/modules/X.Y.Z-gentoo)
  |-------------------          System.Map
  |-------------------          Kernel.Config
  |-------------------          initramfs
  |-------------------          vmlinuz (kernel image)
  ├── packages                  portage patch, and package configurations for profiles 17.X/...
  ├── patchfiles                system wide, generic patch files, independent of profile
  ├── profiles                  machine (virtual/hardware) based profiles, for purpose driven, domain name based 
  ├── releases                  synchronized too, via sync.sh
  ├── repos                     synchronized too, via sync.sh
  ├── snapshots                 synchronized too, via sync.sh
  ├── distfiles                 synchronized too, via sync.sh
  ├── repository                (cgit hosted) git repos for gentoo
  ├── meta                      meta package information, for meta builds (patches, configs, portage is not perfect)
```
  