include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-web-private-net
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-web-private-net
  DEPENDS:=+gluon-web-admin +ffgraz-private-net
  TITLE:=Settings for the node's private network
endef

$(eval $(call BuildPackageGluon,ffgraz-web-private-net))
