# ffac-ap325-no-reset-wipe

Auf dem Aruba AP-32x (APBoot) löscht ein langer Reset-Knopfdruck beim
Starten beide Software-Images **und** die U-Boot-Umgebung
(`factory_reset` → `clear all` + `purgeenv`), noch bevor ein OS startet.
Das ist Arubas vorgesehener Wiederherstellungsweg, kollidiert aber mit
der Gluon-Gewohnheit, über langes Drücken in den Config-Modus zu
gelangen — das Gerät ist dann nicht konfigurierbar, sondern leer.

APBoot überspringt den Löschvorgang, wenn die U-Boot-Umgebungsvariable
`disable_reset_button` exakt `yes` enthält (`execute_config_clear()` in
`board/qca/octomore/ipq806x_cdp.c`, zur Laufzeit gelesen). Dieses Paket
setzt diese Variable auf dem AP-32x beim Erstart und nach jeder
`gluon-reconfigure` (geschrieben wird nur, wenn der Wert fehlt).

Der [Bootloader-Fix](https://github.com/lukasstockner/ap325-apboot-openwrt/pull/7)
entfernt `CONFIG_RESET_BUTTON` komplett und macht das Verhalten dauerhaft
unmöglich — er wirkt aber erst nach einem Neuflash von APBoot. Jedes
laufende Gerät braucht weiterhin die Umgebungsvariable; dieses Paket
liefert sie.

Getestet auf APBoot 1.5.7.2-gf4d79f58 (Gluon-Image ipq806x/aruba_ap-32x):
`fw_setenv` schreibt `/dev/mtd12` (`0:appsblenv`) und der Wert übersteht
`reboot` und `reboot -f`.
