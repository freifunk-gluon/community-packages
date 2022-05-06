# ffda-gluon-usteer

This package provides a Gluon-specific integration, the OpenWrt WiFi roaming & steering daemon.


## Configuration

This package provides a tiered configuration. It is hard to provide a configuration, which covers all possible deployment environments.

The following configuration options can be configured using the site as well as the `gluon-usteer` configuration package.


### network.enabled

Default: 1

Whether usteer contacts adjacent nodes using the mesh-interfaces.


### network.wireless

Default: 1

Enabled networking with remote nodes using wireless mesh-interfaces.


### network.wired

Default: 1

Enabled networking with remote nodes using wired mesh-interfaces.


### network.update_interval

Default: 5

Interval (milliseconds) between node-updates sent.


### network.update_timeout

Default: 12

Number of `network.update_interval` intervals after which a remote-node is deleted.


### band_steering.enabled

Default: 1

Enables band-steering for clients connected on 2.4 GHz


### band_steering.min_snr

Default: -60

Clients require to maintain a SNR / signal better than `band_steering.min_snr` to be steered to 5 GHz.


### band_steering.interval

Default: 40

Clients require to maintain `band_steering.min_snr` for `band_steering.interval` milliseconds in order to be steered to 5GHz.


## Site configuration

The site configuration provides the site-wide default configuration for usteer.
