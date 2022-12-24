integration points

HOW TO USE:

  # SIMPLE LOCAL DEPLOYMENT ... LOCAL ONLY.

  ./deploy.sh build=plasma work=zpool/plasma deploy

  # autosensing for btrfs,zfs,or regular f/s (w/ spec settings, eventually a higher level installer can use yaml/python for exotic configs)
  (concept-btrfs) ./deploy build=plasma work=btrfs_mount/subvol   
  
  (concept-ext4,...) ./deploy build=plasma work=/path/to/rootfs deploy
 

  # UPDATE USR SPACE FOR POOL/SET

  ./update.sh work=pool/set bootpart=/dev/sdX# update

  ./update.sh work=pool/set update

  # NEW DISK + LOCAL OR REMOTE SOURCE

  ./install.sh work=zfs://wSys/hardened@safe boot=zfs:///dev/sda:/usb/g1

  ./install.sh work=zfs://root@10.1.0.1:/wSys/gnome@safe boot=zfs:///dev/nvme0n1:/saturn/g2

  # EXISTING ZFS/DISK (TEST AND MAKE WORK, $DHOST)

  ./install.sh work=zfs://pluto/plasma@safe boot=zfs://wSys/plasma

  # MIRROR URL FOR TYPE OF RESOURCE + PROTOCOL || PROVIDE PROFILE FOR SPECIFIC URL pair FOR A GIVEN PROFILE

  ./mirror.sh ../config/[type]_[remote?].mirrors [protocol type {ftp,rsync,http*}] [PROFILE-releases.mirrors]

  example - ./mirror.sh ../config/releases.mirrors http plasma      # use a http URL reference in the mirrors-file for the xz/asc latest stage3

  example - ./mirror.sh ../config/releases.mirrors file plasma      # use a local file system reference in the mirrors-file for the xz/asc latest stage3

  example - ./mirror.sh ../config/releases.mirrors http sync-only   # 3rd argument is trivial, this will pull down a sync url, for esync

  example - ./mirror.sh ../config/distfiles.mirrors rsync sync-only   # 3rd argument is trivial, in fact, it doesn't have to be stated, pulls down distfiles sync URL

   

  # SYNCHRONIZE BACKEND

  ./esync.sh            # checkout backend spec/folder specification, this script populates about half of the /var/lib/portage directory, but about 99% of the data. 

  # BIGGEST ISSUE : ZFS ONLY.

issues / dependencies : <review>

  [ BACKEND SPEC. | DISTRO SERVER ]
  /var/lib/portage

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

  [ BACKEND SPEC. | BUILD SERVER ]  :: { to reference pkgmx.sh & profile.sh for profiling machines and maintaining bin_pkgs }

  ?       TIME MACHINE BASED REPO REFERENCE (requires metadata build, snapshots...) - GOAL to hit year 2000 /w distfile fetcher

  ?       CUSTOM STAGE 3 GENERATOR FOR TIME MACHINE BUILDS

  ?       PER USE FLAG, PER VERSION, PACKAGE BUILDER (USE SUBVOLs or DATASET) ... BTRFS PROBABLY BEST SUITED FOR TREEING OUT VARIABLE CASE BUILDS

  ?       BUG TRACKING (FROM GENTOO.ORG) & LOCALLY GENERATED BUG REPORTING+LOGGING FACILITIES

  ?       AUTOMATED WORK AROUNDS (FIND WAYS TO TEST FOR WORK AROUNDS, AUTOMATICALLY, SAVE GOOD CATCH AS A PATCH, AND A BUG, W/ CLASS TYPE respecting the PATCH FORMULATION) [pluggable]

  - web serves are too inconsistent and will require 'tests'/QC after syncs/pulls (hashs most likely)

  - NOW MIGRATING TO DYNAMIC HOSTS, etc/hosts will be patched, soon a respectful dhcp/subnet-friendly/dns solution will be required for the dom.0 but before this, i will need to build NEXUS up.

  * VERIFY MODULES ARE INSTALLED ON INSTALL.

  - skipping modules missing program (networking)
  - adsl/pppoe
  - br2684ctl
  - atmsigd/clip
  - netplugd
  - ifplugd
  - ipppd
  - iwoconfig
  - firewald
  - udhcpc/busybox
  - pump
  - dhclient

  - build list of dependencies for this platform, add pkgcore.

  - add meta commands to f/w (ex. fw.meta + fw.sh = tables) the meta file maps out invalid packet specs, and host configs. That said, the current intent to recurse a form of networking through all layers of the network stack, should be attempted, and then modeled afterwards, w/ in the meta config. 

  - better granularity over profile versions, and then move common in to specific versions, then be able to understand the version when patching w/ specific sets. 

  - create a meta-sync (out of sync.sh) for rollups prior to backups/commits
  
  - create an autopatcher script for updating servers, and software patches (basically a portage + sys patch hooked to a server update or emerge --update)

  - centralize the hosting-config for pkg/bld services with new host scripts. I need to be able to turn towards public or private, and between private servers with in one edit.

  - sanitize mget - stream methods, need to check this one closely for most/close to all cases.
  
  - add pkg update to system install, after sync up, before profile packages. No more no-meshing w/ versions

  x

  - should i move to git type sync ? look in to glsa/news/manifests/signing more, need comprehensive list of requirements for git -> rsync conversion.

  - figure out why fstab is not loading up the pool/swap

  ?

  ?

  ?
  
  begin adding comments to all fixes to prevent git comments from being verbose

  x

  add boot resolutions to the [profile], to be patched after deploy-system-[update], alongside the rest of the profile packages/configs.

  x

  x

  please find out where rsync is owning the parent folder (deploy...)

  add wpa_supplicant, and auto spawn for wireless, given an adapter, spawn can be used in fw meta package

      wireless = always LAN
      
      wired = check ip range, LAN = private space ; WAN = public space

      wireguard takes in all LAN + lo + default route

      virbr0 goes to WAN / static routes point to WAN-NET

      wireguard goes to WAN IP, need to define routing exchange


  x

  x - troubleshoot zpool ownwership issues following all scripts !

  ** META PACKAGE, FW NOTES:

    systemd-resolved disabled

    wireguard routing/instantiation/dependency installs

    openrc/systemd installer (./install.sh)

    assets: bastionX.sh, as (/etc/init.d - service) || (systemd unit files + sbin)

    dependency chains for net-tools & ipcalc

    bastionX, accounts for dynamic virttual bridging, and 1 wg interface, domain specific, for the machine its on 


  * bring vscode key, in to meta package, take out of default for desktop profiles.

  !!!!! move lxd-prep in to lxd meta package. virbr0 will be for libvirt, autosensed by fw, virbr1 reserved for lxd, autosensed.

  !!!!! run a service check (base services) w/ update (command [services]) on command line ./update.sh

  !!!!! NEED TO MOVE SCRIPT BASE DIR to project dir, and then prefix with bash, then move esync over to ./config, include stays in ./bash, along with mget, mirror moves to ./config --refactor

  //unmount.exe for unmounting chroots...

    x

  Prospect - profile.sh : ./profile.sh profile=sub.domain.tld work={pool/set}.../ bootpart=/dev/efi_part

  profile.sh - takes in the important settings for a given environment, needs to be modular, including the boot env, and stores them in ./profile/TLD/DOMAIN/SUB
  granularity is only down to subdomain, as this is meant for machines only,  not apps/services inside a cluster like kubernetes,  docker or lxd. 

  TBD.

  domain tools : have a config file for the domain name/server ips, manage all references through a single command/config file.

  x...

  create build services, to serve as an alternative for distfiles complete sync, where only relavent packages will be installed in to distfiles over sshfs/bind mounts. Build service to feature, binpkg versioning, per kernel, per glibc, ... use the local zfs on VM to snapshot per versioning, client versioning to use this as a basis, for it's own.

  g3 clones from g2 snapshot_versioning, from g1@safe.

  better snapshot management, especially for cloning to profile build services

  BTRFS INTEGRATION !!!

  kernel upgrade service, from upgrade script. (local machine upgrade in to kernel tree)

  add zfs key management, before dom-0 ca, must be able to integrate upwards/scale in to dom.0/ca

  x 
  x - partially resolved

  x

  x

  find a way to hash patched server directories, log output, and report differences

  bundles : need meta packages for things like libvirt, to include patches for /etc ... bundles can be placed in /bundle/call/*.pkgs;*.patches/rootdir/...

  x ... live environments/isos are not supported by refind, directly, would require separate gpt partitions, memtest added.

  x
  x

  add support for inclusion of arm+ builds { binpkgs | releases | ... }

  !!!!!! Add bastion4 to rc-conf.d :: new code in to bastion, wait for adapters, and timeout. Perhaps run as a daemon.
  MODIFY BASTION TO ASSOCIATE VIRTUAL BRIDGES, AUTOMATING FIND WAN ADAPTERS or LAN (based on Private Network Space/ vs WAN, possibly use conf.d/net ...) Need 

  x

  !!!!!!! verify nproc works on [update] ... needs to to be addressed, per boot (rc-conf.d) ... install to drive in live env, update not on live image, but to new host, and associate with boot medium. Live env=boot disk.

  CIK ---> live rescue image [boot] ---> install to host disk, update w/ CIK in computer, CIK adds a reference to the host system, rinse and repeat and you have one key for many systems.
  ON A multi-host system, the basis pool can facilitate many different CIK installs, each install is a profile, with a domain name, this is stored on the associated domain 0 for a given domain.
  Any time a CIK boots a host or rescue image, the initramfs can be swapped out for one with new keys, a rescue volume can have new keys loaded to it (post boot env). This is handled completely 
  transparently via ssh. Installs require network connectivity, or a an install derived from the rescue disk itself. 32 GB can facilitate up to two desktop systems, (20GB) and a 8GB EFI partition.
  CIK's up to 250GB can handle many different profiles, and more functionality perhaps, as well as maybe a roaming user space (volume). Disks up to 2TB can serve as a pop in domain 0, or perhaps even 
  another domain component/application service. See Dom.N / Dom.0. Every Dom. is a Virtual Machine, routed through virtual networking, interlinked via encrypted trunks. Every Dom provides Container Application Support.

  check if modules deployed during install (only)

  x
  x

  need option for kernel source ... in deploy ?

  x

  x

  libvirt is not patched. .... PROFILE ASSERT

  !!!!!!     world file, will be over written by portage map, need to rethink ...

  no network profiling ....

  x

  x

  qemu missing : swtpm + usermod-utilities, ssh enabled thru profile ... profile+services capture ... profile+key mngmt/capture

  x

  network addressing / configuration can take place using auto negotiation, utilizing certs, vpn-tun/tap's and dhcp. vpn's require a general client certificate + a private key/auth mechanism

  get rid of @safe snapshot prior to deployment, deployment assumes initialization ...

  !!!!!!!!!!!!!!!!!!!! all ip address scheme - dom.zero 10.0.0.1 (dns resolve pt) .: universal naming convention for the distribution hub, prod.dom.zero and dev.dom.zero
                      all other resolve points will be, if neccessary captured by a patch_sys -> /etc/hosts, for which the rest of the system can elate across the network through name services.

  install will assume the originating dataset's key and mount points, also install does not have a schema build system, where as multiple disks and custom properties cannot be asserted conveniently. 

  Should I give deployment an option for remote destination ? 

  Work+Verify I can install to an existing ZFS (only) pool, this skips disk initialization, setup, but requires a new boot entry

  Needs new_host.sh script to adapt new hardware (make.conf + networking) ; script is run 

  Needs dynamic keylocation assertion @ end of deploy.sh ... eventually tie in to CA/PKI/OLDAP w/ custom prebuilt initramfs 

  x

  x

  x

  need to start using signed packages !

  sequencing snapshots, versioning and updates.

  ....................need to auto configure zfs-loop for swap_memory+autofs.

  x

  x

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

  x
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

