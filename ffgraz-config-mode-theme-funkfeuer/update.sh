#!/bin/bash

set -euo pipefail

gluon="$1"

# do not expand CSS code
# shellcheck disable=SC2016
freifunk='
@charset "utf-8";

$ffyellow:  #ffb400;
$ffmagenta: #dc0067;
$ffzusatz:  #009ee0;
$red:       #ee3300;
'

# do not expand CSS code
# shellcheck disable=SC2016
funkfeuer='
/* Colors adjusted based on the CI from https://download.funkfeuer.at/misc/Funkfeuer-CI/VIguide_FUNKFEUER_last.pdf */

@charset "utf-8";

$feuer_darkblue: #273142;
$feuer_greyblue: #556270;
$feuer_lightblue: #6991aa;
$feuer_red: #f23a14;
$feuer_green: #a1c820;

$ffyellow:  $feuer_green;
$ffmagenta: $feuer_lightblue;
$ffzusatz:  $feuer_darkblue;
$red:       $feuer_red;
'

for f in files i18n sass; do
	rm -rf "$f"
	cp -vrp "$gluon/package/gluon-config-mode-theme/$f" .
done

THEME=$(cat sass/gluon.scss)
THEME_REPLACED=${THEME/"$freifunk"/"$funkfeuer"}

echo "$THEME_REPLACED" > sass/gluon.scss

sass --sourcemap=none -C -t compressed sass/gluon.scss files/lib/gluon/config-mode/www/static/gluon.css

git add .
git commit -m "ffgraz-config-mode-theme-funkfeuer: update"
