in this folder, place working archives [snapshots] OR UNTAR'd contents of the current patchfiles directory on 
the reposerver, git ignores these files, these are system specific files, specific to any individual's implementation.
at any point, all files in this patchfiles directory are no longer to be tracked in git, only through regular 
backup.


[./bash/sync.sh]

./patchfiles

	patchfiles-[base16-EPOCH].tar.gz
	ex. patchfiles-0x63A2C917.tar.gz

OR
	
	[contents] of tar xfvz (via mget)



	README.txt
	.gitignore (*)
