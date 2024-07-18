ff3l-badblocks-disable-autoupdater
=============

Transitional package to be used with last Gluon v2019.1.x release
Simply disables the autoupdater for UBNT ERX devices with bad eraseblocks in flash and prefixes the node's name with "#BADBLOCKS".
This mitigates the issue that these devices would get bricked by an update to Gluon v2020.1 or newer, where the handling of bad eraseblocks has been changed.
(see: https://github.com/oszilloskop/UBNT_ERX_Gluon_Factory-Image/blob/master/ERX-Sysupgrade-Problem.md)
