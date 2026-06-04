# SPDX-FileCopyrightText: 2024 Marius Wehrmann
# SPDX-License-Identifier: BSD-2-Clause
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-private-wan-dhcp
PKG_VERSION:=1.1
PKG_RELEASE:=1

PKG_LICENSE:=BSD-2-Clause

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=bypass FF-Offloading for Direct Network Access for LTE/DSL via Private WAN-Socket
  DEPENDS:=+uradvd
endef

define Package/$(PKG_NAME)/description
  The functionality of this package allows devices connected to a private WAN WiFi to utilize the LTE WAN
  connection directly, without the typical redirection or offloading to local network resources. This is
  achieved by dynamically managing network routing and gateway settings to ensure that all traffic is
  directed through the LTE connection, providing an uninterrupted and low-latency internet experience.

  Includes IPv6 support: the LTE /64 is advertised to private WAN clients via uradvd and an IPv6
  policy-routing rule (rule6) sends their traffic through the LTE routing table instead of the
  Freifunk default route. The rule is (re)created with the current prefix on every uplink ifup.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
