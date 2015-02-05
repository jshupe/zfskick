# zfskick
FreeBSD/ZFS remote incremental backups

This set of scripts utilizes ZFS's incremental send capability to
automatically duplicate snapshots over the network for backup
purposes.

The initial (aka current as of this writing) commit is configured
for a very specific use case. I will be making changes to increase
the flexibility of the scripts in the near future.

The scenario for the initial commit is as follows:

    - Veeam backups are sent to a FreeBSD/ZFS server running Samba,
      on the local network
    - Veeam is configured with an AfterJob script that creates an
      empty file on a Samba share that shares its name with the 
      destination ZFS filesystem
    - The zfskick.sh script runs under cron every minute, watching
      for the aforementioned file(s)
    - When a file is found, it calls kick.sh with the name of the
      file at the appropriate arguments
    - It also moves the file into an ignore folder, to create a lock
    - kick.sh creates a snapshot
    - kick.sh performs several basic checks, and if they pass
    - kick.sh sends the incremental snapshot to the destination 
      server and removes excess copies that are outside the set
      retention policy
    - kick.sh sends an email notification/log and removes the lock
