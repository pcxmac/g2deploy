#!/bin/bash


# host=gitweb.gentoo.org
# works for cgit sites...

host=${1:?}

list="$(lynx -dump -listonly ${host} | awk '{print $2}' | grep .git | uniq)"
format=""

while read -r line
do
	format="${format}\n${line%%.git*}"

done < <(printf '%s\n' "${list}")

format="$(echo -e "${format}" | uniq)"

for repo in ${format}
do
	git clone ${repo}.git
done
