#!/bin/sh
# SPDX-License-Identifier: MIT

set -eu

strip_comments() {
	filename=$1

	# strip comments from all but the first line
	sed -i '2,$s/\s*#.*//' "${filename}"

	# strip first line if it isn't a shebang
	sed -i '1s/\s*#[^!].*//' "${filename}"
}

strip_duplicate_newlines() {
	filename=$1

	# strip empty lines
	sed -i '/^\s*$/d' "${filename}"
}

strip_spaces_around_vertical_bar() {
	filename=$1

	# convert "true | false" to "true|false"
	sed -i 's/\s\+|\s*/|/g' "${filename}"
	# convert "true | false" to "true|false"
	sed -i 's/\s*|\s\+/|/g' "${filename}"
}

strip_spaces_between_semicolon_and_then_or_do() {
	filename=$1

	# convert "if true; then" to "if true;then"
	sed -i 's/;\s\+then/;then/g' "${filename}"

	# convert "for xxx; do" to "for xxx;do" and "; done" to ";done"
	sed -i 's/;\s\+do/;do/g' "${filename}"
}

strip_spaces_around_boolean_operators() {
	filename=$1

	# convert "true && false" to "true&&false"
	sed -i 's/\s*||\s*/||/g' "${filename}"
	sed -i 's/\s*&&\s*/&&/g' "${filename}"
}

strip_trailing_semicolon() {
	filename=$1
	# remove trailing ; excluding ";;" for switch/case clauses
	sed -i 's/\([^;]\);$/\1/' "${filename}"
}

strip_comments "$1"
strip_trailing_semicolon "$1"
strip_duplicate_newlines "$1"
strip_spaces_around_vertical_bar "$1"
strip_spaces_around_boolean_operators "$1"
strip_spaces_between_semicolon_and_then_or_do "$1"
