-- Network

need_boolean({'usteer', 'network', 'enabled'}, false)
need_boolean({'usteer', 'network', 'wireless'}, false)
need_boolean({'usteer', 'network', 'wired'}, false)
need_number({'usteer', 'network', 'update_interval'}, false)
need_number({'usteer', 'network', 'update_timeout'}, false)


-- Band-Steering

need_boolean({'usteer', 'band_steering', 'enabled'}, false)
need_number({'usteer', 'band_steering', 'min_snr'}, false)
need_number({'usteer', 'band_steering', 'interval'}, false)
