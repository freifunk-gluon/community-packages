# ffda-ssh-manager

This is a utility package which allows communities to add their own key-groups using their site-configuration.

Configuration is done using UCI. The following config-keys exist:

- `ffda-ssh-manager.settings.enabled`
  - Default: 0
  - Type: boolean
  - Enables gluon-ssh-manager.
- `ffda-ssh-manager.settings.group`
  - Default: nil
  - Type: list
  - Selects the groups to roll out on a node.

ssh-manager will add the group-keys to the end of dropbears `authorized_keys` file.
This block is identified by a block-start comment. Each key is appended with a comment, associating
these keys with ssh-manager.

Keys with this trailing comment are removed when they are removed from the key-group or ssh-manager becomes
disabled.


## Defaults

Defaults can be defined in the `site.conf`. These will apply to nodes which are first-time installed or where
ssh-manager is initially rolled out to.

If you omit default settings from your `site.conf`, ssh-manager will automatically be disabled with no groups
selected.


## Append behvaior

In case a key is defined in multiple activated groups, the key will only be appended once to `authorized_keys`.

In case a key is manually added to `authorized_keys` (Not ending with the ssh-manager comment trailer) and
the same key is defined in an activated group, the key will still be appended by ssh-manager.

However, the manually added key will persist even when SSH-manager becomes disabled.


## Default site-configuration

```
	ssh_manager = {
    -- Optional ; Default settings
		defaults = {
			enabled = true,
			groups = {
				'admins',
			},
		},
		groups = {
			admins = {
				'ssh-rsa a01 admin01',
				'ssh-rsa a02 admin02',
			},
			community = {
				'ssh-rsa c01 community01',
				'ssh-rsa c02 community02',
			},
		},
	},
```
