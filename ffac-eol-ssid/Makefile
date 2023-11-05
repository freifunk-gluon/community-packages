# This package is based on https://gitlab.karlsruhe.freifunk.net/firmware/packages/-/tree/master/ffka-eol-ssid by Julian Schuh and Simon Terzenbach
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-eol-ssid
PKG_VERSION:=1
PKG_RELEASE:=1

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Changes the SSID for devices with this package. Used to show a deprecation warning in the SSID for unsupported targets
  DEPENDS:=+gluon-core
endef

define Package/ffac-eol-ssid/conffiles
/etc/config/eol-ssid
endef

$(eval $(call BuildPackageGluon,ffac-eol-ssid))
