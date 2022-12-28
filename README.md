###HOW TO USE: (PRE-RELEASE < v0.1) | { v1.x = last stand alone implementation } | ZFS >primary target<
##### <u>SIMPLE LOCAL DEPLOYMENT ... LOCAL ONLY.</u>
  <u>./deploy.sh</u> <b>build=plasma work=zpool/plasma deploy</b>
  <span style="color:red">(not yet implemented) 
  (concept-btrfs) ./deploy build=plasma work=btrfs_mount/subvol\
  (concept-ext4,...) ./deploy build=plasma work=/path/to/rootfs deploy </span>
###
##### <u>UPDATE USR SPACE FOR POOL/SET</u>

  <u>./update.sh</u> <b>work=pool/set bootpart=/dev/sdX# update</b>
  <u>./update.sh</u> <b>work=pool/set update</b>
###
##### <u>NEW DISK + LOCAL OR REMOTE SOURCE</u>

  <u>./install.sh</u> <b>work=zfs://wSys/hardened@safe boot=zfs:///dev/sda:/usb/g1 </b><span style="color:green">(standard installation)</span>
  <u>./install.sh</u> <b>work=zfs://root@10.1.0.1:/wSys/gnome@safe boot=zfs:///dev/nvme0n1:/saturn/g2 </b><span style="color:green">(convert nvme to zpool, new dataset) </span>
  <u>./install.sh</u> <b>work=zfs://root@localhost:/test/hardened@safe add=zfs://saturn/g2 (add to existing pool, add/modify boot record) </b><span style="color:red"> >TESTING< </span>
###
##### <u>MIRROR URL FOR TYPE OF RESOURCE + PROTOCOL </u>
  <u>./mirror.sh</u> <b>../config/patchfiles.mirrors rsync</b>
  <span style="color:blue">ex. output => "rsync://pkg.hypokrites.me/gentoo/patchfiles" (URI for patchfiles rsync access) </span>

  <u>./mirror.sh</u> <b>../config/releases.mirrors http plasma</b> <span style="color:red"> (releases mirror requires 3 arguments, all others are type and protocol)</span>
  <span style="color:blue">http://pkg.hypokrites.me/gentoo/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/stage3-amd64-desktop-openrc-20221205T133149Z.tar.xz</span>
  <span style="color:blue">http://pkg.hypokrites.me/gentoo/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/stage3-amd64-desktop-openrc-20221205T133149Z.tar.xz.asc</span>

  <u>./mirror.sh</u> <b>../config/releases.mirrors rsync hardened</b>
  <span style="color:blue">rsync://mirrors.rit.edu/gentoo/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-20221225T170313Z.tar.xz</span>
  <span style="color:blue">rsync://mirrors.rit.edu/gentoo/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-20221225T170313Z.tar.xz.asc</span>

  <u>./mirror.sh</u> <b>../config/kernel.mirrors ftp</b>\
  <span style="color:blue">ftp://pkg.hypokrites.me/kernels/current/</span>\


<u>./mirror.sh</u> <b>../config/package.mirrors http</b>\
<span style="color:blue">http://pkg.hypokrites.me/gentoo/packages</span>\

<u>./mirror.sh</u> <b>../config/distfiles.mirrors rsync</b>\
<span style="color:blue">rsync://mirror.csclub.uwaterloo.ca/gentoo-distfiles/distfiles</span>\
####
<span style="color:red"><b>*</b> : </span> which servers are enabled/disabled (commented out), are controlled by the *.mirrors files in ../config

  ###
  ##### <u>SYNCHRONIZE BACKEND</u>

  <u>./esync.sh</u>            # checkout backend spec/folder specification, this script populates about half of the /var/lib/portage directory, but about 99% of the data. 

###
###  [ BACKEND SPEC. ]
  /var/lib/portage 
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
  ├── releases                  synchronized too, via esync.sh
  ├── repos                     synchronized too, via esync.sh
  ├── snapshots                 synchronized too, via esync.sh
  ├── distfiles                 synchronized too, via esync.sh
  ├── meta                      meta package information, for meta builds (patches, configs, portage is not perfect)
```
  