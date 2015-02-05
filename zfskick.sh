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
