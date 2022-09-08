#!/bin/bash

rsync -avP --delete-before rsync://mirror.csclub.uwaterloo.ca/gentoo-distfiles/releases/amd64 ./releases/
