include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-gluon-usteer
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Gluon integration for the usteer daemon
  DEPENDS:=+gluon-core +usteer
endef

define Package/$(PKG_NAME)/description
  Gluon integration for the usteer daemon.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
