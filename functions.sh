function killAll() {
	ps aux | grep $1 | awk '{print $2}' | xargs kill -9
}

function UPDATE() {
	pSyu $@ && ySyu $@
}
