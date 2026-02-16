# proxmox-helpers
This is a set of simple bash scripts to manage a 3-2-1 backup of proxmox to two external pbs servers. It has been setup to start and auto shutdown a server on the local network with Wake on LAN support. And a second that uses a Home Assistant connected switch to do the same (with safe shutdown). IT also intergrates with home assistant to easily control shutdown and backup permissions.

The wake on LAN scripts are labeled wol and the Home Assistant Swich scripts are labeled sw
The remote start scripts must be setup on a cron schedule and it is recogmened to leave sufficent time before the backup comences.
``apt install wakeonlan curl jq``


The shutdown scripts should be connected to the proxmox backup as "hook" scripts

``pvesh get /cluster/backup``
``pvesh set /cluster/backup/backup-code --script script-name.sh``
You will also have to enable shutdown with no password
and set up key based ssh access from the machine running proxmox to the backup server
