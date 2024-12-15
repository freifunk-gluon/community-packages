include $(TOPDIR)/rules.mk

PKG_NAME:=ffbs-parker-nodeconfig-respondd
PKG_VERSION:=1

PKG_MAINTAINER:=Chris Fiege <chris@tinyhost.de>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffbs-parker-nodeconfig-respondd
  TITLE:=respondd module for nexthop and gateway info on parker gateway nodes
  DEPENDS:=+respondd +kmod-nlmon
endef

define Package/ffbs-parker-nodeconfig-respondd/description
  Respndd module for parker-based networks.
endef

$(eval $(call BuildPackageGluon,ffbs-parker-nodeconfig-respondd))
