include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-olsr-public-ip
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-olsr-public-ip
  TITLE:=olsr public ip support
  DEPENDS:= +ffgraz-l3routes +gluon-firewall +kmod-ipip +ipip
endef

$(eval $(call BuildPackageGluon,ffgraz-olsr-public-ip))

