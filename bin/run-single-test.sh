#!/bin/bash
set ${MMTESTS_SH_DEBUG:-+x}

DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME/.." && pwd`
FAILED=no
P="run-single-test"
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh

if [ "$MMTESTS" = "" ]; then
	. $SCRIPTDIR/config
fi

function die() {
        echo "FATAL: $@"
        exit -1
}

setup_dirs

#setup of core scheduling
#if ENABLE_CORE_SCHEDULING is set to "yes" then core scheduling is enabled
#if ENABLE_CORE_SCHEDULING_START_PID is set to a <pid>, then the test will be added to the core scheduling group of <pid>

#the following var is used to control the behaviour of core scheduling in multi-bench.
#if ENABLE_CORE_SCHEDULING_ON_TEST is set to the test curently running (ie. sysbenchcpu), then core scheduling will be set only to that test
#if ENABLE_CORE_SCHEDULING_ON_TEST is set but not to the currently running test, core scheduling will not be set on the current test
#if ENABLE_CORE_SCHEDULING_ON_TEST is not set, but ENABLE_CORE_SCHEDULING is, core scheduling will be set to all the test

if [ "$ENABLE_CORE_SCHEDULING" == "yes" ]; then
	#if not root,
	if [[ "$EUID" -ne 0 ]]; then
		echo "WARNING: You are not running test as root, which is required in order to set up core scheduling."
		echo "Test will continue without core scheduling"
	fi

	if ! type "coreschedtool" &> /dev/null;  then #if root but coreschedtool is not present
		echo
		echo "You have not installed coreschedtool, which is required to use core scheduling."
		echo "coreschedtool will be downloaded from https://github.com/marcoSanti/coreschedtool and installed on your system"
		echo

		git clone https://github.com/marcoSanti/coreschedtool.git $SHELLPACK_SOURCES/coreschedtool
		make -C $SHELLPACK_SOURCES/coreschedtool install DESTDIR="$SCRIPTDIR/bin"

	fi
	#set core scheduling only if test is not multi and if not on install_only, and test is run as root
	if [ "$INSTALL_ONLY" != "yes" ] && [ "$1" != "multi" ]; then
		#if the test is the one specified into ENABLE_CORE_SCHEDULING_ON_TEST (or if notthing is specified)
		if [ "$ENABLE_CORE_SCHEDULING_ON_TEST" == "$1" ] || [ "$ENABLE_CORE_SCHEDULING_ON_TEST" == "" ]; then
			#if it is required to add the test to an already existing core scheduling group
			if ["$ENABLE_CORE_SCHEDULING_START_PID" == ""]; then
				coreschedtool -v $$
			else
				coreschedtool -v -add $$ -to $ENABLE_CORE_SCHEDULING_START_PID
			fi
		#if the current test is not the one on ENABLE_CORE_SCHEDULING_ON_TEST
		else
			coreschedtool -clear $$
		fi
	fi
fi

#end of core scheduling setup


# Load the driver script
NAME=$1
if [ "$NAME" = "" ]; then
	echo Specify a test to run
	exit -1
fi
if [ -z "$SHELLPACK_LOG" ]; then
	echo "SHELLPACK_LOG has to be set"
	exit -1
fi
if [ ! -e $SCRIPTDIR/drivers/driver-$NAME.sh ]; then
	echo A driver script called driver-$NAME.sh does not exist
fi
shift
. $SCRIPTDIR/drivers/driver-$NAME.sh

# Logging parameters
export LOGDIR_TOPLEVEL=$SHELLPACK_LOG/$NAME$NAMEEXTRA
rm -rf $SHELLPACK_LOG/$NAME$NAMEEXTRA
mkdir -p $LOGDIR_TOPLEVEL
cd $LOGDIR_TOPLEVEL

# Check that server/client execution is supported if requested
if [ "$REMOTE_SERVER_HOST" != "" ]; then
	if [ "$SERVER_SIDE_SUPPORT" != "yes" ]; then
		die Execution requested on server side but $NAME does not support it
		exit $SHELLPACK_ERROR
	fi
	if [ "$SERVER_SIDE_BENCH_SCRIPT" = "" ]; then
		SERVER_SIDE_BENCH_SCRIPT="shellpacks/shellpack-bench-$NAME"
	fi
	export REMOTE_SERVER_WRAPPER=$SCRIPTDIR/bin/config-wrap.sh
	export REMOTE_SERVER_SCRIPT=$SCRIPTDIR/$SERVER_SIDE_BENCH_SCRIPT
	mmtests_server_init
fi

NR_HOOKS=`ls $PROFILE_PATH/profile-hooks* 2> /dev/null | wc -l`
if [ $NR_HOOKS -gt 0 ]; then
	for PROFILE_HOOK in `ls $PROFILE_PATH/profile-hooks-*.sh 2> /dev/null`; do
		echo Processing profile hook $PROFILE_HOOK title $PROFILE_TITLE
		. $PROFILE_HOOK
	done

	export MONITOR_PRE_HOOK=`pwd`/monitor-pre-hook
	export MONITOR_POST_HOOK=`pwd`/monitor-post-hook
	export MONITOR_CLEANUP_HOOK=`pwd`/monitor-cleanup-hook
fi

export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/logs
mkdir logs
setup_dirs

# Always start from first available node
if [ "`which taskset`" != "" -a "`which numactl`" != "" ]; then
	taskset -pc `numactl --hardware | grep cpus: | awk -F : '{print $2}' | head -1 | sed -e 's/^\s*//' -e 's/ /,/g'` $$
	taskset -pc 0-4096 $$
fi

save_rc run_bench 2>&1 | tee /tmp/mmtests-$$.log
mv /tmp/mmtests-$$.log $LOGDIR_RESULTS/mmtests.log
recover_rc
check_status $NAME "returned failure, unable to continue"
gzip $LOGDIR_RESULTS/mmtests.log

rm -rf $SHELLPACK_TEMP
exit $EXIT_CODE
