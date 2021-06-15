include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-purge-contact-info
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/ffda-purge-contact-info
  TITLE:=Purge contact-info on a Gluon node
  DEPENDS:=+gluon-core
endef

define Package/ffda-purge-contact-info/description
  Simple package to remove user-entered contact information.
endef

$(eval $(call BuildPackageGluon,ffda-purge-contact-info))
