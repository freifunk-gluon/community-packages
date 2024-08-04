ffbs-debugbathosts
==================

This script provides means to map MAC addresses to names for `batctl`.

This is done with two components:

* `/etc/bat-hosts` is a mapping file consumed by `batctl`.
  It is delivered empty and only contains help for the user.
  It is mostly intended as a reminder that this functions exists at all.
* `update-bat-hosts` is a lua-script that loads a `nodes.json` from a given URL
  and populates `/etc/bat-hosts` with the nodes found.
