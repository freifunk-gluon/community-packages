include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-private-ap
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-private-ap
  TITLE:=Provides a virtual access point for the nodes client network
  DEPENDS:=+gluon-core
endef

$(eval $(call BuildPackageGluon,ffgraz-private-ap))
