# SPDX-FileCopyrightText: 2023 Florian Maurer (FFAC), grische (FFMUC)
# SPDX-License-Identifier: GPL-2.0-or-later
# This package is based on https://gitlab.karlsruhe.freifunk.net/firmware/packages/-/tree/master/ffka-eol-ssid by Julian Schuh and Simon Terzenbach

include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-eol-ssid
PKG_VERSION:=1
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Changes the SSID for devices with this package. Used to show a deprecation warning in the SSID for unsupported devices/targets
  DEPENDS:=+gluon-core
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/eol-ssid
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
