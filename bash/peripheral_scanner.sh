#!/bin/bash

# this will scan the PCIe BUS

# lspci -PPkDv	# ROUTE + attributes
# 		# HWIDs
# 

# scan USB
# scan Hard Drives
#   /sys/devices ... link to the targetX and allow interrogating HD Stats/driver/... use HWINFO for networking other stats
#   /sys/block/... partitions are represented by folders, interrogate those folders if not disk utility ...
#	/sys/block/... (readlink)
# 	smartctl
#	hdparm
# scan sensors (temperature/fan/...)


-- create a way to simplify the scan's yaml file, in order to build things like zfs zpools. or to inquire UUIDs, or to ...

