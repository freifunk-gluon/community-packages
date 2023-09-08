include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-gluon-usteer
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/ffda-gluon-usteer
  TITLE:=Gluon integration for the usteer daemon
  DEPENDS:=+gluon-core +usteer
endef

define Package/ffda-gluon-usteer/description
  Gluon integration for the usteer daemon.
endef

$(eval $(call BuildPackageGluon,ffda-gluon-usteer))
