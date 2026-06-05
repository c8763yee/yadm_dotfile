function findsym() {
	local kw="$1"
	rg -- "$kw" /proc/kallsyms
}
