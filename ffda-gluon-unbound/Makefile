include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-gluon-unbound
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Drop-in replacement for the local node resolver
  DEPENDS:=+gluon-core +unbound-daemon +ca-bundle
endef

define Package/$(PKG_NAME)/description
  Drop-in replacement for the local node resolver
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
