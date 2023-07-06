#!/bin/bash

# this will scan the PCIe BUS
# eventually this will supplement udev and monitor the state/changes of peripheral devices (security)


# lspci -PPkDv	# ROUTE + attributes
# lspci -vmn    # slot info (IDs, which will be sub attributes for the text)
# lspci -vm     # text for ids

#   
#   Sort devices through the ROUTE
#   every routable device, has a list item called Devices: where any device which is on the branch will be indicated.
#   every non routable device, ie a peripheral/terminal device will be in the ROOT chain. So all the hubs, bridges, etc.. will be linked, and other devices will be off the root complex
#    
#
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
#           sysfs:
#           procfs:
#
#


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
# scan sensors (temperature/fan/...)


#-- create a way to simplify the scan's yaml file, in order to build things like zfs zpools. or to inquire UUIDs, or to ...

drives="$(ls /sys/block)"

for drive in $drives
do
    (
smartctl -t long /dev/${drive}
	)
done
