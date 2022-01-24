$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh netperf
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh kernbench
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh tbench4
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh sysbenchcpu

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-multi
	return $?
}
