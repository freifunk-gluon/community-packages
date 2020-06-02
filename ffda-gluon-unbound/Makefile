include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-gluon-unbound
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/ffda-gluon-unbound
  TITLE:=Drop-in replacement for the local node resolver
  DEPENDS:=+gluon-core +unbound-daemon
endef

define Package/ffda-gluon-unbound/description
  Drop-in replacement for the local node resolver
endef

$(eval $(call BuildPackageGluon,ffda-gluon-unbound))
