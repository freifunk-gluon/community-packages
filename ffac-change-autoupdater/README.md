# ffac-change-autoupdater

Change the autoupdater branch after on upgrade.
This is needed to switch the autoupdater branch after releasing a migration or getting back testing devices to stable.

# Usage

Add the package to the `site.mk` after adding the community-packages repository to `modules`.
Add the following to the `site.conf`:

```
update_channel = {
    --from_name = false, -- remove or false to catch all
    -- if to_name is defined, autoupdater branch is set to it on upgrade
    to_name = 'stable',

}
```

## Related packages

* https://github.com/eulenfunk/packages/tree/v2020.1.x/eulenfunk-migrate-updatebranch
* https://github.com/freifunkMUC/gluon-packages/tree/main/ffmuc-autoupdater-next2stable
* https://github.com/freifunkMUC/gluon-packages/tree/main/ffmuc-autoupgrade-experimental2testing
* https://github.com/freifunkh/ffh-packages/tree/master/ffh-autoupdater-to-stable
* https://github.com/tecff/gluon-packages/tree/main/tecff-autoupdater-to-stable
