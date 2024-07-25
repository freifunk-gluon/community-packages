# ffac-update-location-gps

This package configures gluon to update the location based on tty output of an attached GPS device.

When a USB device which provides a tty is attached, it updates the location based on the output of it.
This is done using a lua rewrite of the script from the original forum posting.
It seems to work without coreutils-stty installed, which did fail the installation when selected as package dependency.

The location is only updated in memory - and only if a valid GPS fix is available.
After a reboot, the old location from the config is set.

## hotplug limitation

After a sysupgrade/autoupdate - the USB dongle has to be unplugged and plugged in once for the detection to work again.
For reboots, this works fine as is.

## further information

Further information can be found here:

* https://github.com/dmth/gluon-gps-locationupdate
* https://forum.freifunk.net/t/freifunk-location-update-via-gps/1493