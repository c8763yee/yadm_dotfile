[[ -o interactive ]] || return 0

function findsym() {
	local kw="$1"
	rg -- "$kw" /proc/kallsyms
}
