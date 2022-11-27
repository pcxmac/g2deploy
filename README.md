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

  # EXISTING ZFS/DISK (TEST AND MAKE WORK, $DHOST)

  ./install.sh work=zfs://pluto/plasma@safe boot=zfs://wSys/plasma

  # MIRROR URL FOR TYPE OF RESOURCE + PROTOCOL || PROVIDE PROFILE FOR SPECIFIC URL pair FOR A GIVEN PROFILE

  ./mirror.sh ../config/[type]_[remote?].mirrors [PROFILE-releases.mirrors || protocol type {ftp,rsync,http*}]

  # SYNCHRONIZE BACKEND

  ./esync.sh            # uses ../config/ESYNC/*.mirrors

  # BIGGEST ISSUE : ZFS ONLY.

issues / dependencies : <review>

  find a way to hash patched server directories, log output, and report differences

  bundles : need meta packages for things like libvirt, to include patches for /etc ... bundles can be placed in /bundle/call/*.pkgs;*.patches/rootdir/...

  put in a timer for waiting for the server should it be offline, post a warning to check the source location. (MGET)

  deploy , news items are not read

  deploy, kernel modules not installed

  deploy is accruing packages in /var/lib/portage ...

  need option for kernel source ... in deploy

  /var/db/pkg & /var/db/repos still exist, pkg was filled ....

  a system update might be getting rid of the spi-... issues

  chromium still has the spi issues

  libvirt is not patched. .... PROFILE ASSERT

  world file, will be over written by portage map, need to rethink ...

  no network profiling ....

  move plasma back over to sddm

  missing completion for gentoo-zsh

  qemu missing : swtpm + usermod-utilities, ssh enabled thru profile ... profile+services capture ... profile+key mngmt/capture

  distfiles not accessible remotely w/out sshfs-autofs

  network addressing / configuration can take place using auto negotiation, utilizing certs, vpn-tun/tap's and dhcp. vpn's require a general client certificate + a private key/auth mechanism

  get rid of @safe snapshot prior to deployment, deployment assumes initialization ...

  all ip address scheme - dom.zero 10.0.0.1 (dns resolve pt) .: universal naming convention for the distribution hub, prod.dom.zero and dev.dom.zero
  all other resolve points will be, if neccessary captured by a patch_sys -> /etc/hosts, for which the rest of the system can elate across the network through name services.

  install will assume the originating dataset's key and mount points, also install does not have a schema build system, where as multiple disks and custom properties cannot be asserted conveniently. 

  Should I give deployment an option for remote destination ? 

  Work+Verify I can install to an existing ZFS (only) pool, this skips disk initialization, setup, but requires a new boot entry

  Needs new_host.sh script to adapt new hardware (make.conf + networking) ; script is run 

  Needs dynamic keylocation assertion @ end of deploy.sh ... eventually tie in to CA/PKI/OLDAP w/ custom prebuilt initramfs 

  install is still downloading everything in the kernels/current, need to isolate, to only the X.X.X-gentoo folder.

  not mounting BOOT folder w/ nvme on saturn, not storing boot spec accordingly, BOOTEDIT works.

  NetworkManager not starting on boot w/ GNOME profile

  need to start using signed packages !

  sequencing snapshots, versioning and updates.

  need to auto configure zfs-loop for swap_memory+autofs.

  patches needs to be slective for a particular folder, / ; /root /home /etc ...

  I believe that the kernel source was being pulled in with the kernel boot env, during bootedit.

  pkg signing keys + kernel_source (signing_module_key) needs to reside on Dom0

  EFI_signing , from safe_image, ... custom_key + appropriated_HW + procedure + thumb drive it seems ...
  try to find a way to assign keys from live environment (automated) 

  consider FUSE-encrypted file systems for cloud or publicly facing appliances. per process/user

  conversion script for pkg to signed package format : GPKG

  patch for roaming profiles ... also zsh.history_db integration.

  -user roaming (sync -OLDAP, ... ?)

  -machine roaming (snapshot w/ customization) .. think crypto_ignition_key<>

  -need a suplimentary dataset || subvol || partition setup for things like home. ... supplimentary configs ? (probably best for after GUI)

  :: perhaps a SSO - CIK, w/ an initramfs which overlays the roaming machine over a default, then snaps from r-o to rw g3 dataset (single boot)

 - dom0 needs to run on UTC

pkg-mx :

  use cases: REBUILD_MISSING_PKGS ; DELETE_REDUNDANT_PACKAGES ; MULTI_VARIATE_USE_BUILD ; LOGGING_FACILITY

  need utility for examining imposed uses flags, and list of packages against binpkg repo Packages file.
  this utility can be used to filter out already built packages satisfying use/version for missing bin package use case.

  need a filter for sweeping through Packages in order to find redundant entries and their associated bin pkg, delete if not 'pretend'.

  utility for rebuilding any package, with all combinations of use flags
    
  logging facility for catching broken package builds during audit.


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


CONCEPT:

  DOM-0 / 

    plug in to any machine, auto associates, connects to cloud VPN, auto updates/syncs.
    requirement - decent machine which can host a DOM-0 VM. 
    SIZE ... needs to be at least 8TB

