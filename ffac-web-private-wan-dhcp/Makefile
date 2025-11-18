include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-web-private-wan-dhcp
PKG_VERSION:=1
PKG_RELEASE:=1

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=gluon-web module to enable and disable ffac-private-wan-dhcp
  DEPENDS:=+gluon-web-admin +ffac-private-wan-dhcp
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
