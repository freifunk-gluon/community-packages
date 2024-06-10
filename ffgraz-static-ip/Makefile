include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-static-ip
PKG_VERSION:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Static IP assignment and configuration for gluon
  DEPENDS:=+gluon-core +luci-lib-ip
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
