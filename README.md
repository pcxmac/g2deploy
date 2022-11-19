integration points

HOW TO USE:

  ./deploy.sh BUILD={PROFILE} WORK=ZPOOL/DATASET DEPLOY

  ./deploy.sh build=plasma work=zpool/plasma deploy

  ./update.sh work=pool/set bootpart=/dev/sdX# update

  ./install.sh work=zfs://wSys/hardened@safe boot=zfs:///dev/sda:/usb/g1

  ./install.sh work=zfs://root@10.1.0.1:/wSys/gnome@safe boot=zfs:///dev/nvme0n1:/saturn/g2

  ./mirror.sh ../config/[type]_[remote?].mirrors [PROFILE-releases.mirrors || protocol type {ftp,rsync,http*}]

  ./esync.sh // uses ../config/ESYNC/*.mirrors




issues / dependencies :

  install will assume the originating dataset's key and mount points, also install does not have a schema build system, where as multiple disks and custom properties cannot be asserted conveniently. 


portage/

  *infrastructure\
  distfiles       # install data\
  snapshots       # portage tree snapshots, daily or every other daily\
  repos           # repo portage tree, THE most up todate sync\
  releases        # sys releases repo, install medium / stage3\
  binpkgs         # binpkg repo
  
  *g2d\
  patchfiles      # specific config files (etc/...)\
  packages        # package and conf files, per profile, such as hardened, selinux, gnome, gnome/systemd\
  profiles        # configs for real/virtual machines, host/domain name dependent\
  kernels         # repo for current and depricated kernels


working on:

  btrfs+xfs+ext4 integration [ install.sh ]
  UPDATE deploy script, modernize w/ mget() on some ops, like install_kernel


needs:

  update function
  
  review install function
  further updates per f/s and schema added

  network adapter mapping