ffho-ap-timer
=============

Timer for the client wifi with three modes (daily, weekly, monthly)

/etc/config/ap-timer
-------------------

**ap-timer.settings.enabled:**
- `0` disables the ap-timer (default)
- `1` enables the ap-timer

**ap-timer.settings.type:**
- `day`, $day = all
- `week`, $day = [Mon|Tue|Wed|Thu|Fri|Sat|Sun]
- `month`, $day = [01-31]

**ap-timer.$day.on:**
- List of time to enable wireless

**ap-timer.$day.off:**
- List of time to disable wireless

### example
```
config ap-timer 'settings'
	option enabled '1'
	option type 'week'

config week 'Sun'
	list on '06:00'
	list off '23:00'
```
