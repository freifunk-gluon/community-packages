# ffac-update-location-gps

This package configures gluon to update the location based on tty output of an attached GPS device.

When a USB device which provides a tty is attached, it updates the location based on the output of it.
This is done using a lua rewrite of the script from the original forum posting.
It seems to work without coreutils-stty installed, which did fail the installation when selected as package dependency.

The location is only updated in memory - and only if a valid GPS fix is available.
After a reboot, the old location from the config is set.

## behvario and lockfiles

This creates a lockfile `/var/lock/hotplug-update-location-gps_$DEVNAME.lock` per found TTY device and sets up a cron job which runs every 5 minutes to check if coordinates are available from the stream.
If the TTY is not in use, the open stream waits for the first line to be read (never) and is stuck.
A lockfile `/var/lock/update-location-gps_$TTYDEVICE` is used to check if the cron is already running/stuck and does not start another reading terminal in that case.

On creation and removal of the micron.d job, the micron.d service is restarted


## further information

Further information can be found here:

* https://github.com/dmth/gluon-gps-locationupdate
* https://forum.freifunk.net/t/freifunk-location-update-via-gps/1493