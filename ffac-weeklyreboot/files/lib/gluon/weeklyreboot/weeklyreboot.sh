#!/bin/sh
DELAYTIME=$(</dev/urandom sed 's/[^[:digit:]]\+//g' | head -c4)
logger -s -t "ffac-weeklyreboot" -p 5 "scheduled reboot in $DELAYTIME seconds"
sleep "$DELAYTIME"
logger -s -t "ffac-weeklyreboot" -p 5 "scheduled reboot in 5 seconds"
sleep 5
# Autoupdate?
upgrade_started='/tmp/autoupdate.lock'
if [ -f $upgrade_started ] ; then
  logger -s -t "ffac-weeklyreboot" -p 5 "Autoupdate running! Aborting"
  exit 2
 fi
reboot
