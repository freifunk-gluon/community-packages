include $(TOPDIR)/rules.mk

PKG_NAME:=ffh-wifi-offline-ssid
PKG_VERSION:=1
PKG_RELEASE:=1

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Changes the SSID to an Offline-SSID on disrupted internet connection
  DEPENDS:=+gluon-core +ffh-check-connection
endef

define Package/$(PKG_NAME)/description
  Script to change the SSID to an Offline-SSID when there is no connection to
  the internet. This SSID can be generated from the node's hostname with the
  first and last part of the node's name or from the MAC address.
  The script is being triggered by ffh-check-connection on connection status
  changes.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
