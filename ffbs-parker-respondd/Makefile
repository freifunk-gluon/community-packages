include $(TOPDIR)/rules.mk

PKG_NAME:=ffbs-parker-respondd
PKG_VERSION:=2

PKG_MAINTAINER:=Chris Fiege <chris@tinyhost.de>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffbs-parker-respondd
  TITLE:=respondd module for nexthop, gateway, traffic and client info on parker nodes
  DEPENDS:=+respondd +kmod-nlmon +libiwinfo +libuci
endef

define Package/ffbs-parker-respondd/description
  Respndd module for parker-based networks.
endef

# respondd merges the modules in the order of their file names. For the same
# key, the last module wins. The "zz-" prefix puts this module after
# gluon-mesh-batman-adv and gluon-radv-filterd, so that traffic and gateway
# come from this module.
define Package/ffbs-parker-respondd/install
	$(INSTALL_DIR) $(1)/usr/lib/respondd
	$(CP) $(PKG_BUILD_DIR)/respondd.so $(1)/usr/lib/respondd/zz-$(PKG_NAME).so
endef

$(eval $(call BuildPackageGluon,ffbs-parker-respondd))
