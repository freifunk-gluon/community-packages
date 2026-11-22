#!/usr/bin/env bash
# Build community packages inside the OpenWrt SDK container
# (ghcr.io/openwrt/sdk), using the Gluon checkout for the Gluon packages
# and the feed versions Gluon pins.
#
# Expected mounts:
#   /gluon      Gluon checkout
#   /package    Gluon's package directory. The SDK is in /builder, so the
#               "include $(TOPDIR)/../package/gluon.mk" of the community
#               packages resolves to /package/gluon.mk.
#   /feed       community-packages checkout
#   /artifacts  writable directory that receives the built packages
#
# Environment:
#   PACKAGES    packages to build, separated by spaces

set -euo pipefail

group() {
	echo "::group::$*"
}

endgroup() {
	echo "::endgroup::"
}

cd /builder

# Release images already contain the SDK, whereas snapshot images download
# it with setup.sh on first start.
if [ ! -f rules.mk ]; then
	group "Download SDK"
	bash setup.sh
	endgroup
fi

# shellcheck source=/dev/null
. /gluon/modules

group "feeds.conf"
{
	# Use the base feed of the SDK, but as a shallow clone from GitHub.
	sed -n \
		-e 's,^src-git-full ,src-git ,' \
		-e 's,https://git.openwrt.org/openwrt/,https://github.com/openwrt/,' \
		-e '/^src-[a-z-]* base /p' \
		feeds.conf.default
	echo "src-link gluon_base /gluon/package"
	echo "src-link community /feed"
	for feed in $GLUON_FEEDS; do
		prefix="PACKAGES_$(echo "$feed" | tr '[:lower:]-' '[:upper:]_')"
		repo="${prefix}_REPO"
		commit="${prefix}_COMMIT"
		echo "src-git $feed ${!repo}^${!commit}"
	done
} | tee feeds.conf
endgroup

group "Update feeds"
./scripts/feeds update -a
endgroup

failed=()

is_failed() {
	[[ " ${failed[*]} " == *" $1 "* ]]
}

# Install the packages one by one, so that a missing dependency only fails
# the package that needs it.
group "Install packages"
for pkg in $PACKAGES; do
	log="$(./scripts/feeds install -p community "$pkg" 2>&1)"
	echo "$log"
	if grep -q 'No feed for package' <<< "$log"; then
		failed+=("$pkg")
		grep 'No feed for package' <<< "$log" | while IFS= read -r line; do
			echo "::error title=${pkg}::${pkg}: ${line#WARNING: }"
		done
	fi
done
endgroup

# Select only the requested packages and their dependencies, like a Gluon
# build, because the SDK default CONFIG_ALL=y would also build every
# installed package, e.g. all mac80211 drivers and all hostapd variants.
{
	echo '# CONFIG_ALL is not set'
	echo '# CONFIG_ALL_KMODS is not set'
	echo '# CONFIG_ALL_NONSHARED is not set'
	echo 'CONFIG_GLUON_SITEDIR="/gluon/contrib/ci/minimal-site"'
	for pkg in $PACKAGES; do
		is_failed "$pkg" || echo "CONFIG_PACKAGE_${pkg}=m"
	done
} >> .config

# A Gluon build relies on the site to select dependencies without "+", e.g.
# the routing protocol, because they are not selected automatically. The SDK
# does not apply the site's package selection, so select the dependencies of
# all community and Gluon packages here. A dependency on a virtual package,
# e.g. gluon-mesh-batman-adv, selects its provider.
make -s prepare-tmpinfo
awk '
	/^Source-Makefile: / { ours = ($2 ~ /(^|\/)feeds\/(community|gluon_base)\//) }
	/^Package: / { pkg = $2; real[pkg] = 1 }
	/^Provides: / {
		for (i = 2; i <= NF; i++)
			if (!($i in provider))
				provider[$i] = pkg
	}
	ours && /^Depends: / {
		for (i = 2; i <= NF; i++)
			if ($i ~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/)
				deps[$i] = 1
	}
	END {
		for (dep in deps)
			print "CONFIG_PACKAGE_" ((dep in real || !(dep in provider)) ? dep : provider[dep]) "=m"
	}
' tmp/.packageinfo | sort -u >> .config

group "make defconfig"
make defconfig
endgroup

build=()
for pkg in $PACKAGES; do
	is_failed "$pkg" && continue

	if ! grep -q "^CONFIG_PACKAGE_${pkg}=[ym]$" .config; then
		echo "::notice title=${pkg}::${pkg} is not available for this target, skipping it"
		continue
	fi
	build+=("$pkg")
done

built() {
	compgen -G "bin/packages/*/community/${1}_*.ipk" > /dev/null ||
		compgen -G "bin/packages/*/community/${1}-[0-9]*.apk" > /dev/null
}

# Build all packages with a single make call to avoid the overhead of one
# make call per package and to build independent dependencies in parallel.
# With -k, a failing package doesn't stop the others.
if [ "${#build[@]}" -gt 0 ]; then
	targets=()
	for pkg in "${build[@]}"; do
		targets+=("package/$pkg/compile")
	done

	group "Build packages"
	make -j"$(nproc)" -k "${targets[@]}" || true
	endgroup
fi

# Rebuild each package that produced no package file in a separate make call
# with V=s, so that the log shows its error.
for pkg in "${build[@]}"; do
	built "$pkg" && continue

	group "Rebuild $pkg with V=s"
	make "package/$pkg/compile" V=s || failed+=("$pkg")
	endgroup

	if is_failed "$pkg"; then
		echo "::error title=${pkg}::${pkg} failed to build"
	fi
done

if [ -d bin/packages ]; then
	find bin/packages -path '*/community/*' -type f -exec cp {} /artifacts/ \;
fi

if [ "${#failed[@]}" -gt 0 ]; then
	echo "Failed packages: ${failed[*]}"
	exit 1
fi
