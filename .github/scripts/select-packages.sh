#!/usr/bin/env bash
# Select the packages the build workflow compiles and write them as
# "packages=<space separated list>" to $GITHUB_OUTPUT.
#
# Environment:
#   EVENT_NAME      GitHub event that triggered the workflow
#   CHANGED_FILES   changed files (push and pull_request) as JSON array,
#                   as produced by dorny/paths-filter with list-files: json
#   CI_CHANGED      "true" if the build CI itself changed
#   INPUT_PACKAGES  packages requested via workflow_dispatch (may be empty)

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

all_packages() {
	local makefile
	for makefile in */Makefile; do
		echo "${makefile%/Makefile}"
	done
}

changed_packages() {
	local file dir
	jq -r '.[]' <<< "${CHANGED_FILES:-[]}" | while IFS= read -r file; do
		[[ "$file" == */* ]] || continue
		dir="${file%%/*}"
		if [ -f "$dir/Makefile" ]; then
			echo "$dir"
		fi
	done | sort -u
}

requested_packages() {
	local pkg ret=0
	for pkg in $INPUT_PACKAGES; do
		if [[ ! "$pkg" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || [ ! -f "$pkg/Makefile" ]; then
			echo "::error::Unknown package: $pkg" >&2
			ret=1
		fi
		echo "$pkg"
	done
	return "$ret"
}

case "$EVENT_NAME" in
push|pull_request)
	if [ "${CI_CHANGED:-false}" = true ]; then
		packages="$(all_packages)"
	else
		packages="$(changed_packages)"
	fi
	;;
workflow_dispatch)
	if [ -n "${INPUT_PACKAGES:-}" ]; then
		packages="$(requested_packages)"
	else
		packages="$(all_packages)"
	fi
	;;
*)
	packages="$(all_packages)"
	;;
esac

# These packages can't be built with the feeds of a stock Gluon build.
declare -A excluded=(
	[ffgraz-static-ip]="depends on luci-lib-ip from the LuCI feed, which Gluon does not include"
	[ffgraz-web-static-ip]="depends on ffgraz-static-ip, which needs luci-lib-ip from the LuCI feed"
)

selected=()
for pkg in $packages; do
	if [ -n "${excluded[$pkg]:-}" ]; then
		echo "::notice title=${pkg}::${pkg} is not built: ${excluded[$pkg]}"
		continue
	fi
	selected+=("$pkg")
done
packages="${selected[*]}"

echo "Selected packages: ${packages:-(none)}"
echo "packages=$packages" >> "$GITHUB_OUTPUT"
