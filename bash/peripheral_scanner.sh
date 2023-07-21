#!/bin/bash

# this will scan the PCIe BUS
# eventually this will supplement udev and monitor the state/changes of peripheral devices (security)

#   helpers : 
#       bus routing (generates yaml of all devices, and their bus structure)
#       module => hwID db, parsed, in yaml
#       hwDB_IDs (pcie,usb) in yaml
#              
#
#   installer requirement:
#   
#       hard drives (usb / pcie)=>ata
#       all devices/modules => kernel config { usb,pcie }
#       firmwares ... module dependent. { appears to look like >> FIRMWARE_<DRIVER> "...fs$" << }
#           or MODULE_FIRMWARE... not standardized !!! impossible to tell really. too many variations.
#           find ./ -type f | \grep -i 'c$' | xargs grep -i "firmware"

# lspci -PPkDv	# ROUTE + attributes
# lspci -vmn    # slot info (IDs, which will be sub attributes for the text)
# lspci -vm     # text for ids

#   
#   Sort devices through the ROUTE
#   every routable device, has a list item called Devices: where any device which is on the branch will be indicated.
#   every non routable device, ie a peripheral/terminal device will be in the ROOT chain. So all the hubs, bridges, etc.. will be linked, and other devices will be off the root complex
#    
#   A device, is any physical entity on the computer, from a chip, to a switch. 
#
#   Device: XX:XX.X
#        Devices:
#           - bridge
#           - bridge
#           - NIC ...
#       ID:
#       Class: @@@@@@
#           ID:xxxx
#       Vendor: @@@@@@@@@@
#           ID:xxxx
#       SVendor:
#           ID:xxxx
#       SDevice:
#           ID:xxxx
#       Rev:
#       ProgIf:
#       Subsystem:
#       Flags:
#       IO Ports:
#       Memory:
#       Capabilities
#           - [XX] @@@
#       Modules: 
#           - @@@
#           - @@@@@
#       Module: @@@@
#           
#
#

#       to probe w/ a vendor/product ID, which kernel module aliases are available :
#           modprobe -c | grep 'vendorID.*productID'
#           or create a decoder function alongside modinfo || /usr/src/linux/drivers/* 
#           :: find ./ -type f | \grep '.c$' | xargs grep -i '^MODULE_ALIAS'
#
#           
#           ^module_alias ... <class>:<id sequence>*<signifiers>
#           usb = usb:v06F8pE031d*dc*dsc*dp*ic*isc*ip*in*
#           pci = pci:v00001002d000073A5sv*sd*bc*sc*i
#           eisa = ...
#           of =
#           platform =
#           hid = 
#           spi = 

# scan USB
#
#   lsusb (summary)
#   lsusb -s bus:device
#
#   usb-devices (more attributes)
#   
#   /sys/bus/usb/devices/{bus-device...} to get kernel module
#
#   use UDEV to monitor changed states/
#
#   usb device template
#   [card/hub]
#   BUS:
#   
#       DEVICE:
#           idVendor:xxx
#           idProduct:xxx

#           bcdDevice:xxx
#           bcdUSB:2.01
#           bDeviceClass:
#           iManufacturer:
#           iProduct: 
#
#

# scan Hard Drives
#   /sys/devices ... link to the targetX and allow interrogating HD Stats/driver/... use HWINFO for networking other stats
#   /sys/block/... partitions are represented by folders, interrogate those folders if not disk utility ...
#	/sys/block/... (readlink)
# 	smartctl
#	hdparm

#   /sys/class
#   /sys/modules
#   /sys/devices

# scan sensors (temperature/fan/...)
# BOOT ENTRIES !!!
# rc.conf ? (boot.log)
# dmesg ?
# bastion -> to modify autofs to facilitate dynamic boot drive mounting. \sed | rc-service
# NETWORK STRATEGIES ... CLASSICAL MODEL of Bifurcated local->wide-arean networking.
# META FILE SYSTEMS ....
# local and network strategies/daemons. Standard allocations @ enumerated types.
# begin to roll in process management in to firewall. Signed applications ? (decoded by public key), authorized by private user.
# sentry user.

# VISION : META + Strategies {Framework + Processing}.

# META : SELinux package
#   scanner needs to enable selinux opportunitistic targeting for profiling. (IE, installed applications/directories{usr space})
#   perhaps, an ancillary process which manages signing executables, can also be used to SEmanage port/permissions/AC.
# ******** NEED TO UPDATE --UPDATE-- to address rc.conf and logging, specifically boot logging.
# monitor selinux logs, especially in permissive mode to 'learn' appropriate mappings.


#-- create a way to simplify the scan's yaml file, in order to build things like zfs zpools. or to inquire UUIDs, or to ...

drives="$(ls /sys/block)"

for drive in $drives
do
    (
smartctl -t long /dev/${drive}
	)
done
