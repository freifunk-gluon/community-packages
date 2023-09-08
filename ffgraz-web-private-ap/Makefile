include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-web-private-ap
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-web-private-ap
  DEPENDS:=+gluon-web-admin +ffgraz-private-ap
  TITLE:=UI for activating a private AP
endef

$(eval $(call BuildPackageGluon,ffgraz-web-private-ap))
