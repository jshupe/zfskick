#!/bin/sh

REMHOST="1.2.3.4"

# Create the file /data/kick/ignore/$NAME
# if you want to suspend kicks for a certain backup. Remove
# it when you want it to run again.

# iterate through the kick folder but ignore the "ignore" and ".zfs" dirs
for NAME in $(ls /data/kick | grep -vE '^ignore$|^.zfs$'); do
    # immediately get rid of the kick file
    rm -f /data/kick/$NAME

    # check for ignore file and exit if it exists
    if [ -f /data/kick/ignore/$NAME ]; then
        echo "Not running kick $NAME due to lock at /data/kick/ignore/$NAME."
        exit 0
    fi

    # kick off the backup
    if [ -d /data/$NAME ]; then
        touch /data/kick/ignore/$NAME
        /root/bin/kick.sh data/$NAME $REMHOST data/$NAME root
    fi
done
