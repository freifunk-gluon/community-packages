#!/bin/bash
#
# Rebuild the layout this package keeps of its own from gluon's config mode
# theme.
#
# It is a fork rather than a copy: the runtime config mode always shows the
# admin category, no matter which page is open, and it has a banner for changes
# that are saved but not yet applied. Everything else - the menu, the markup,
# the styling - should follow the theme, and used to drift because there was no
# way to pull it across.
#
#   ./update.sh <path/to/gluon-repo>
#
# Every patch has to match. A theme that moved on shows up as a failure here
# rather than as a layout that quietly lost the runtime behaviour.

set -euo pipefail

gluon="${1:?usage: update.sh <path/to/gluon-repo>}"

src="$gluon/package/gluon-config-mode-theme/files/lib/gluon/config-mode/view/theme/layout.html"
dst="files/lib/gluon/config-mode-runtime/view/theme/layout.html"

[ -f "$src" ] || { echo "update.sh: no theme layout at $src" >&2; exit 1; }

layout=$(cat "$src")

patch() {
	local what="$1" search="$2" replace="$3" before="$layout"

	layout=${layout/"$search"/"$replace"}

	if [ "$layout" = "$before" ]; then
		echo "update.sh: could not apply '$what' - the theme layout has changed" >&2
		exit 1
	fi
}

# The category is always admin here: the runtime config mode is the settings,
# and the page being shown does not pick the menu.
patch 'admin category' \
'	local category = request[1]' \
'	local real_category = request[1]
	local category = '"'"'admin'"'"''

patch 'menu of the admin category' \
'		subtree({path}, root.nodes[category], ...)' \
'		subtree({category}, root.nodes[category], ...)'

# Wizard and the like are reachable, but not worth a tab on a running node.
patch 'hide hidden categories' \
'					<li><a class="topcat<% if request[1] == r then %> active<%end%>" href="<%|url({r})%>"><%|title(root.nodes[r])%></a></li>' \
'					<% if not root.nodes[r].hidden then %>
						<li><a class="topcat<% if request[1] == r then %> active<%end%>" href="<%|url({r})%>"><%|title(root.nodes[r])%></a></li>
					<% end %>'

# Nothing is applied while the node is running until someone says so, so say
# that something is waiting.
patch 'pending changes banner' \
'			</noscript>' \
'			</noscript>

			<% if uci:get_bool('"'"'gluon'"'"', '"'"'core'"'"', '"'"'reconfigure'"'"') and (real_category ~= '"'"'apply'"'"') then %>
				<div style="margin: 1em 2em;" class="gluon-section">
					<div class="gluon-section-descr" style="display: flex; justify-content: space-between; align-items: center;">
						<div><%:Pending changes - Changes will be applied automatically on next reboot%></div>

						<div>
							<a href="/cgi-bin/config/apply"><div class="gluon-button gluon-button-submit"><%:Apply now...%></div></a>
						</div>
					</div>
				</div>
			<% end %>'

printf '%s\n' "$layout" > "$dst"

echo "update.sh: rebuilt $dst from the theme"
