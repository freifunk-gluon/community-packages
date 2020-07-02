include $(TOPDIR)/rules.mk

PKG_NAME:=ffka-gluon-web-usb-wan-hotplug
PKG_VERSION:=1
PKG_RELEASE:=1

include $(TOPDIR)/../package/gluon.mk

define Package/ffka-gluon-web-usb-wan-hotplug
  TITLE:=gluon-web module to enable and disable ffda-usb-wan-hotplug
  DEPENDS:=+gluon-web-admin +ffda-usb-wan-hotplug
endef

$(eval $(call BuildPackageGluon,ffka-gluon-web-usb-wan-hotplug))
