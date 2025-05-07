# ffda-gluon-usteer

This package provides a Gluon-specific integration, the OpenWrt WiFi roaming & steering daemon.

## Usefullness

this is especially useful, if

- a Freifunk network needs to provide a consistent client experience by automatically steering clients to stronger access points based on signal strength and bandwidth.
- mesh networks consisting of multiple nodes need to be optimized to prevent congestion and maximize throughput.
- seamless roaming between 2.4 GHz and 5 GHz networks is desired without connection interruptions.
- an overview of the network structure and topology is required to identify bottlenecks and weak connections.


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

Default: 5000

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

Default: 40000

Clients require to maintain `band_steering.min_snr` for `band_steering.interval` milliseconds in order to be steered to 5GHz.


## Site configuration

The site configuration provides the site-wide default configuration for usteer.

## Example

To fully leverage the capabilities of the `ffda-gluon-usteer` package in your Gluon firmware, you can add the following usteer configuration block to your `site.conf` file:

    usteer = {
      max_signal_diff = 10,
      min_signal = -75,
      roam_trigger = -70,
      signal_avg_weight = 0.5,
      load_balancing = true,
    }

This configuration enables decentralized client steering, allowing clients to be automatically directed to the most suitable access point based on signal strength and load balancing considerations.

If we want to maximize the functionality of **ffda-gluon-usteer**, we should consider the following options:

- **Client Steering** based on signal strength and load balancing  
- **Band Steering** between 2.4 GHz and 5 GHz  
- **Network Monitoring and Updates**  

```lua
usteer = {
  network = {
    enabled = true,
    wireless = true,
    wired = true,
    update_interval = 5000,
    update_timeout = 12,
  },
  band_steering = {
    enabled = true,
    min_snr = -60,
    interval = 20000,
  },
  client_steering = {
    max_signal_diff = 10,
    min_signal = -75,
    roam_trigger = -70,
    signal_avg_weight = 0.5,
    load_balancing = true,
  }
}

