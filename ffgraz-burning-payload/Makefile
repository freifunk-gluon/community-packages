include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-burning-payload
PKG_VERSION:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-burning-payload
  TITLE:=Skip setup mode, set configuration options
  DEPENDS:=+gluon-core
endef

$(eval $(call BuildPackageGluon,ffgraz-burning-payload))

