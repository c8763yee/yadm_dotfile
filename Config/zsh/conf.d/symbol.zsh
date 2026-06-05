function findsym(){
	kw=$1
	rg $kw /proc/kallsyms
}
