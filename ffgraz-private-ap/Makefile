include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-private-ap
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Provides a virtual access point for the nodes client network
  DEPENDS:=+gluon-core
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
