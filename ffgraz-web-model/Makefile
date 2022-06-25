include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-web-model

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-web-model
  TITLE:=Module that adds custom web-model elements to gluon-web-model
  DEPENDS:=+gluon-web-model
endef

$(eval $(call BuildPackageGluon,ffgraz-web-model))

