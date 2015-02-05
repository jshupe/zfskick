#!/bin/sh

# Copyright (c) 2015, James Shupe <j@jamesshupe.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## NOTE
## You must perform a full zfs send|zfs recv before using this script
## zfs snapshot pool/vol@`date +%s`
## zfs list -t snapshot
## zfs send -R pool/vol@1370363092 | ssh $ARGS $HOST zfs recv -Fv pool/vol

SNAP_MAX_AGE="432000"
MINSNAP="5"				# Minimum amount of snaps to have at any time
SNAP_MAX_AGE="1209600"                  # Set to age of max snapshot, 1209600 = two weeks
					# WARNING. If this is set too low, you could delete
					# the last snapshot accidentally and have to do a full
					# to get things back in sync.
SSHARGS="-c blowfish"
SNAPVOLU=$1
REMOTEHOST=$2
REMOTEVOL=$3
EMAIL=$4

if [ "$EMAIL" != "" ]; then
    exec 1> /tmp/$$.out
    exec 2> /tmp/$$.err
fi

if [ -z $REMOTEVOL ]; then
    echo "usage: $0 local/pool/vol remotehost remote/pool/vol"
    echo "eg. $0 data/veeam host.domain.tld vol/veeam-backup [email-address]"
    if [ -f $LOCKFILE ]; then
        rm -f $LOCKFILE
    fi
    exit 1
fi

# Make sure $SNAPVOLU exists
if [ ! -d /$SNAPVOLU ]; then
    echo "Volume $SNAPVOLU not found"
    if [ -f $LOCKFILE ]; then
        rm -f $LOCKFILE
    fi
    exit 1
fi

# Make sure we can SSH to $REMOTEHOST
ssh -q $SSHARGS $REMOTEHOST exit
if [ $? != 0 ]; then
    echo "SSH to $REMOTEHOST failed!"
    if [ -f $LOCKFILE ]; then
        rm -f $LOCKFILE
    fi
    exit 1
fi


LOCKFILE=/data/kick/ignore/`basename $SNAPVOLU`

# Make sure we can write to $REMOTEHOST:$REMOTEVOL
ssh -q $SSHARGS $REMOTEHOST "touch /$REMOTEVOL/.delme; rm /$REMOTEVOL/.delme" 2> /dev/null
if [ $? != 0 ]; then
    echo "Could not write to $REMOTEVOL on $REMOTEHOST!"
    if [ -f $LOCKFILE ]; then
        rm -f $LOCKFILE
    fi
    exit 1
fi

SNAPTIME=`date +%s`
LASTSNAP=`ssh -q $REMOTEHOST /sbin/zfs list -t snapshot -o name -s creation | grep $REMOTEVOL\@ | tail -1`
LASTSNAP=`echo $LASTSNAP | cut -d '@' -f 2`
LASTSNAP="$SNAPVOLU@$LASTSNAP"

# Destroy any local snaps older than $SNAP_MAX_AGE
for SNAP in `/sbin/zfs list -t snapshot -o name -s creation | grep $SNAPVOLU\@`; do
    TIMESTAMP=`echo $SNAP | cut -d '@' -f 2`
    SNAPDIFF=`expr $SNAPTIME - $TIMESTAMP`
    if [ $SNAPDIFF -gt $SNAP_MAX_AGE ]; then
        SNAPCNT=`/sbin/zfs list -t snapshot -o name -s creation | grep $SNAPVOLU\@ | wc -l | awk '{ print $1 }'`
        if [ $SNAPCNT -gt $MINSNAP ]; then
            echo "Destroying local snapshot $SNAP"
            /sbin/zfs destroy $SNAP
        fi
    fi
done

# Destroy any remote snaps older than $SNAP_MAX_AGE
for SNAP in `ssh $REMOTEHOST zfs list -t snapshot -o name -s creation | grep $REMOTEVOL\@`; do
    TIMESTAMP=`echo $SNAP | cut -d '@' -f 2`
    SNAPDIFF=`expr $SNAPTIME - $TIMESTAMP`
    if [ $SNAPDIFF -gt $SNAP_MAX_AGE ]; then
        SNAPCNT=`ssh $REMOTEHOST /sbin/zfs list -t snapshot -o name -s creation | grep $REMOTEVOL\@ | wc -l | awk '{ print $1 }'`
        if [ $SNAPCNT -gt $MINSNAP ]; then
            echo "Destroying remote snapshot $SNAP"
            ssh $REMOTEHOST zfs destroy $SNAP
        fi
    fi
done

# Take current snapshot
echo "Creating current snapshot - $SNAPVOLU@$SNAPTIME"
/sbin/zfs snapshot $SNAPVOLU@$SNAPTIME

# Create incremental comparison to the last snapshot, send to $REMOTEHOST:/$REMOTEVOL
echo "Sending incremental snapshot to $REMOTEHOST:/$REMOTEVOL"
/sbin/zfs send -R -I $LASTSNAP $SNAPVOLU@$SNAPTIME | ssh $SSHARGS $REMOTEHOST zfs receive -Fv $REMOTEVOL

if [ "$EMAIL" != "" ]; then
    SUBJECT="ZFSkick OK: $REMOTEHOST:/$REMOTEVOL"
    printf "Output Log:\n---\n" > /tmp/$$.msg
    cat /tmp/$$.out >> /tmp/$$.msg
    ERRLINES=`/usr/bin/wc -l /tmp/$$.err | /usr/bin/awk '{ print $1 }'`
    if [ $ERRLINES -gt 0 ]; then
        SUBJECT="ZFSkick ERROR: $REMOTEHOST:/$REMOTEVOL"
        printf "\nError Log:\n---\n" >> /tmp/$$.msg
        cat /tmp/$$.err >> /tmp/$$.msg
    fi
    /usr/bin/mail -s "$SUBJECT" $EMAIL < /tmp/$$.msg
    rm /tmp/$$.out /tmp/$$.err /tmp/$$.msg
fi

if [ -f $LOCKFILE ]; then
    rm -f $LOCKFILE
fi
