
function m_get()	#source	#destination	#config
{
	# supports local destinations only, right now.

	local destination=$2
	local source=$1
	local src_url="invalid"
	local origin="$(realpath ${BASH_SOURCE:-$0})"
	origin="${origin%/*/${0##*/}*}"

	case ${3} in
		bin*)		src_url="$(${origin}/bash/mirror.sh ${origin}/config/binpkg.mirrors *)"
					echo "${src_url}"
		;;
		kern*)		src_url="$(${origin}/bash/mirror.sh ${origin}/config/kernel.mirrors *)"
					echo "${src_url}"
		;;
		pkg|pack*)	src_url="$(${origin}/bash/mirror.sh ${origin}/config/package.mirrors *)"
					echo "${src_url}"
		;;
		patch*)		src_url="$(${origin}/bash/mirror.sh ${origin}/config/patchfiles.mirrors *)"
					echo "${src_url}"
		;;
		rel*)		src_url="$(${origin}/bash/mirror.sh ${origin}/config/releases.mirrors *)"
					echo "${src_url}"
		;;
		rep*)		src_url="$(${origin}/bash/mirror.sh ${origin}/config/repos.mirrors *)"
					echo "${src_url}"
					# NOT USABLE, REFERENCE ONLY, USED FOR LOCAL MIRROR SYNC
		;;
		snap*)		src_url="$(${origin}/bash/mirror.sh ${origin}/config/snapshots.mirrors *)"
					echo "${src_url}"
					# NOT USABLE, REFERENCE ONLY, USED FOR LOCAL MIRROR SYNC
		;;
	esac;




}

