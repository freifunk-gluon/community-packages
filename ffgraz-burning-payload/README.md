# ffgraz-burning-payload

Ship predefined config in your image

Add the following to site.conf

```
burning = {
  gluon-section = {
    create = {
      { 'type', 'key', {
        option = 'value',
      }
    },
    set = {
      { 'key', 'option', 'value' }
    }
  }
}
```

Add ffgraz-burning-payload to site.mk

Build image like that

```
make GLUON_TARGET=<TARGET> GLUON_RELEASE=0.0 GLUON_AUTOUPDATER_BRANCH=beta GLUON_AUTOUPDATER=enabled
```

Device will autoupdate afterwards, this will ensure we're getting rid of the weird image asap
