include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-olsr-auto-restart
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Automatically restart olsr
  DEPENDS:= +gluon-mesh-olsrd +micrond
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
