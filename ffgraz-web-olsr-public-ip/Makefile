include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-web-olsr-public-ip
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-web-olsr-public-ip
  DEPENDS:=+gluon-web-admin +ffgraz-olsr-public-ip +ffgraz-l3routes
  TITLE:=UI for setting up olsr public ips
endef

$(eval $(call BuildPackageGluon,ffgraz-web-olsr-public-ip))
