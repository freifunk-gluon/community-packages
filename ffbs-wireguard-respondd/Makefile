include $(TOPDIR)/rules.mk

PKG_NAME:=ffbs-wireguard-respondd
PKG_VERSION:=1

PKG_MAINTAINER:=Chris Fiege <chris@tinyhost.de>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffbs-wireguard-respondd
  TITLE:=Respondd support for wireguard.
  DEPENDS:=+respondd +kmod-wireguard
endef

define Package/ffbs-nodeconfig-respndd/description
  Respondd support for wireguard.
endef

$(eval $(call BuildPackageGluon,ffbs-wireguard-respondd))
