# SPDX-FileCopyrightText: 2024 Marius Wehrmann
# SPDX-License-Identifier: BSD-2-Clause
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-private-wan-dhcp
PKG_VERSION:=1.0
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
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
