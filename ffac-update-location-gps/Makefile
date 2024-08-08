# SPDX-FileCopyrightText: 2024 Florian Maurer, xelo
# SPDX-License-Identifier: MIT
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-update-location-gps
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Use attached GPS controller to update location from it
  DEPENDS:=+kmod-usb-core +kmod-usb-ohci +kmod-usb2 +kmod-usb-acm +kmod-usb-serial-pl2303 +micrond
endef

define Package/$(PKG_NAME)/description
  If enabled, this package updates the gluon-node-info location based on the NMEA output of an attached GPS device.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
