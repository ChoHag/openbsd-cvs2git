#!/bin/bash

. ~/.bashrc

MYDIR=$(dirname $0)
TODAY=$(date '+%Y-%m-%d')

LOGDIR=$MYDIR/logs
LOGFILE=sync.log
LOGFILE_TODAY=$LOGFILE.$TODAY
LOGPATH_TODAY=$LOGDIR/$LOGFILE_TODAY

setup_before() {
    if [ ! -d $LOGDIR ]; then
        mkdir -p $LOGDIR
        return $?
    else
        return 0
    fi
}

log() {
    declare level=$1
    shift
    declare message="$*"
    declare logtime=$(date '+%Y-%m-%d %H:%M:%S');

    echo "$logtime $level - $message" >> $LOGPATH_TODAY
}

wait_before() {
    declare sleep_time=$(($RANDOM % 300 + 1))
    log INFO "Waiting for $sleep_time sec..."
    sleep $sleep_time
    return 0
}

cvsync() {
    declare retval=0

    log INFO 'cvsync started...'
    /opt/cvsync/bin/cvsync -c $MYDIR/cvsync.conf >> $LOGPATH_TODAY 2>&1
    retval=$?    

    if [ $retval -eq 0 ]; then
        log INFO 'cvsync succeeded'
    else
        log ERROR 'cvsync failed'
    fi

    return $retval
}

cvsimport() {
    declare retval=0

    log INFO 'git-cvsimport started...'
    git cvsimport.latin -d :local:$(cd $MYDIR/cvs && pwd) -vakR -p -x -C $MYDIR/git -S '^gnu/usr\.bin/gcc/INSTALL$' src >> $LOGPATH_TODAY 2>&1
    if [ $retval -eq 0 ]; then
        log INFO 'git-cvsimport succeeded'
    else
        log ERROR 'git-cvsimport failed'
    fi

    return $retval
}

push_to_remote() {
    declare retval=0

    log INFO 'git push --all started...'
    git --git-dir=$MYDIR/git/.git/ push --all origin >> $LOGPATH_TODAY 2>&1
    retval=$?    
    if [ $retval -eq 0 ]; then
        log INFO 'git push --all succeeded'
    else
        log ERROR 'git push --all failed'
        return $retval
    fi

    log INFO 'git push --tags started...'
    git --git-dir=$MYDIR/git/.git/ push --tags origin >> $LOGPATH_TODAY 2>&1
    retval=$?    
    if [ $retval -eq 0 ]; then
        log INFO 'git push --tags succeeded'
    else
        log ERROR 'git push --tags failed'
    fi

    return $retval
}

compress_logs() {
    find $LOGDIR -name "$LOGFILE.[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" ! -name $LOGFILE_TODAY -exec bzip2 {} \;
}



( setup_before && wait_before && cvsync && cvsimport && push_to_remote && compress_logs ) &


