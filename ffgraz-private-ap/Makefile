include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-private-ap
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-private-ap
  TITLE:=A wifi access point onto the node's private network
  DEPENDS:=+gluon-core +ffgraz-extra-networks +gluon-private-wifi
endef

$(eval $(call BuildPackageGluon,ffgraz-private-ap))
