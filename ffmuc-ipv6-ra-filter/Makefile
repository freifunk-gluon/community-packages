include $(TOPDIR)/rules.mk

PKG_NAME:=ffmuc-ipv6-ra-filter
PKG_VERSION:=1
PKG_RELEASE:=1

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Filters router advertisments of any gateway but the connected gateway
  DEPENDS:=+gluon-ebtables +libgluonutil +libbatadv
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
