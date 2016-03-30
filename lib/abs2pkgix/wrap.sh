version="${pkgver}-${pkgrel}"
website="${url:-}"
description="${pkgdesc:-}"
provides+=("${pkgname[@]}")

builddepends=("${makedepends[@]:+${makedepends[@]}}")

_set_vars() {
	srcdir="$(pwd)"
	pkgdir="${destdir}"
}

isinstalled() {
	local headerpath
	local old_IFS

	for filepath in "${_isinstalled_list[@]:+${_isinstalled_list[@]}}"; do
		old_IFS="$IFS"
		IFS=":"
		for path in "" "${CPATH[@]}"; do
			# Get prefix (PKGIX_PREFIX may be unset)
			path="${path%/include}"
			path="${path%/usr}"

			if [[ -f "${path}${filepath}" ]]; then
				return 0
			fi
		done
		IFS="$old_IFS"
	done

	return 1
}

iscompat() {
	[[ "$ostype" == "linux" ]] || return 1
	in_list "any" "${arch[@]}" \
		|| in_list "$architecture" "${arch[@]}"
}

# parse a source spec like ${pkgname}-${pkgver}.tar.gz::"https://github.com/open-source-parsers/${pkgname}/archive/${pkgver}.tar.gz"
# e.g. for jsoncpp
#
my_get_fetch_target() {
	local source_spec="$1"
	local replace
	replace=$(echo "$source_spec" | awk 'BEGIN {FS="::"; ORS="\t"} {for(i=1;i<=NF;i++)print $i}')
	IFS=$'\t' read -ra source_spec_parts <<< "$replace"
	if [[ ${#source_spec_parts[@]} -eq 2 ]]; then
		echo "${source_spec_parts[0]}"
	else
		echo "$(get_fetch_target "$source_spec")"
	fi
}
my_get_url() {
	local source_spec="$1"
	local replace
	replace=$(echo "$source_spec" | awk 'BEGIN {FS="::"; ORS="\t"} {for(i=1;i<=NF;i++)print $i}')
	IFS=$'\t' read -ra source_spec_parts <<< "$replace"
	if [[ ${#source_spec_parts[@]} -eq 2 ]]; then
		echo "${source_spec_parts[1]}"
	else
		echo "$source_spec"
	fi
}

_fetch_sources() {
	local i
	local url
	local source_spec
	local checksum
	local file_name
	for (( i=0 ; i < ${#source[@]}; ++i )); do
		source_spec="${source[i]}"
		checksum="${_checksums[i]}"
		file_name="$(my_get_fetch_target "$source_spec")"
		url="$(my_get_url "$source_spec")"

		if [[ "$file_name" == "$url" ]]; then
			url="${repo}/../support/${pkgname}/${url}"
		fi

		if [[ "$checksum" == "SKIP" ]]; then
			arg_ignore_checksums=1 fetch "$url" "$checksum" "$file_name"
		else
			fetch "$url" "${_checksums_digest}=$checksum" "$file_name"
		fi

		( extract_archive "$file_name" &>/dev/null ) || :
	done
}

prepare() {
	_fetch_sources

	type -p _prepare &>/dev/null || return 0
	_set_vars
	_prepare
}

build() {
	type -p _build &>/dev/null || return 0
	_set_vars
	_build
}

check() {
	type -p _check &>/dev/null || return 0
	_set_vars
	_check || warning_printf "Check failed!\n"
}

installenv() {
	_set_vars

	type -p package &>/dev/null && package || :

	declare -F | while read line; do
		read -ra split_line <<< "$line"
		if [[ "${split_line[2]}" =~ ^package_ ]]; then
			package_func="${split_line[2]}"
			_p="${package_func#package_}"
			msg_printf "installing split %s ...\n" "$_p"
			$package_func
		fi
	done
}

#forceinstall
#postinstall
#preremove
#postremove
