#!/bin/bash

# see if one exists ?
#gpg --list-secret-keys --keyid-format=long

#sleep 5

#gpg --delete-secret-key ${name}

#gpg --full-generate-key

#gpg --armor --export ${public_key}

#git config --global user.signingkey ${key}

# setting up pinentry

app-crypt/gnupg

eselect pinentry list/set (gnome)

~/.gnupg/gpg-agent.conf

	pinentry-program /usr/bin/pinentry
	no-grab
	default-cache-ttl 1800

~/.gnupg/gpg.conf

	use-agent

gpg-connect-agent reloadagent /bye

(ok)

GPG agent can be used via SSH (see dom0/authCA_GPG+)
https://wiki.gentoo.org/wiki/GnuPG#Using_a_GPG_agent

plasma requires extra work for autobooting gpg-agent apparently...

gpg --full-generate-key 

#this will prompt gnome to intercept and take passphrase), I believe gnome uses its wallet to store the passphrase, need to investigate settingup wallet on other systems !!!




copy ssh and gnupg subfolders in to same user's directory

copy gitconfig to users directory

vscode should prompt for a web login to github

--- this will allow you to pass through ssh, but not gpg, for gpg, you have to register properly

for vscode, you will have to enable commit signing, through the file/preferences/settings, upon setting this
the new push will prompt pinentry, and you can use gnome to save your key, through a password.






https://wiki.archlinux.org/title/GNOME/Keyring

