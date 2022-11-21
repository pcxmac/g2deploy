integration points

HOW TO USE:

  # SIMPLE LOCAL DEPLOYMENT ... REMOTE ?

  ./deploy.sh build=plasma work=zpool/plasma deploy

  # UPDATE USR SPACE FOR POOL/SET

  ./update.sh work=pool/set bootpart=/dev/sdX# update

  ./update.sh work=pool/set update

  # NEW DISK + LOCAL OR REMOTE SOURCE

  ./install.sh work=zfs://wSys/hardened@safe boot=zfs:///dev/sda:/usb/g1

  ./install.sh work=zfs://root@10.1.0.1:/wSys/gnome@safe boot=zfs:///dev/nvme0n1:/saturn/g2

  # EXISTING ZFS/DISK

  ./install.sh work=zfs://pluto/plasma@safe boot=zfs://wSys/plasma

  # MIRROR URL FOR TYPE OF RESOURCE + PROTOCOL || PROVIDE PROFILE FOR SPECIFIC URL pair FOR A GIVEN PROFILE

  ./mirror.sh ../config/[type]_[remote?].mirrors [PROFILE-releases.mirrors || protocol type {ftp,rsync,http*}]

  # SYNCHRONIZE BACKEND

  ./esync.sh            # uses ../config/ESYNC/*.mirrors




issues / dependencies :

  install will assume the originating dataset's key and mount points, also install does not have a schema build system, where as multiple disks and custom properties cannot be asserted conveniently. 

  Should I give deployment an option for remote destination ? 

  Work+Verify I can install to an existing ZFS (only) pool, this skips disk initialization, setup, but requires a new boot entry

  Needs new_host.sh script to adapt new hardware (make.conf + networking) ; script is run 

  Needs dynamic keylocation assertion @ end of deploy.sh ... eventually tie in to CA/PKI/OLDAP w/ custom prebuilt initramfs 

  install is still downloading everything in the kernels/current, need to isolate, to only the X.X.X-gentoo folder.

  not mounting BOOT folder w/ nvme on saturn, not storing boot spec accordingly, BOOTEDIT works.

  NetworkManager not starting on boot w/ GNOME profile

  need to start using signed packages !


Supplimental infrastructure

  LXD @ Boot + BASIC DOM-N bridging + auto configuring firewall

oddities

  plasma doesn't boot
  sysop/root profiles do not have a good gnome or plasma preferences, for the terminal, or desktop, etc...


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