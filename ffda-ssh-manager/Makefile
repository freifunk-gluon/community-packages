include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-ssh-manager
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Package to provide group-based SSH key management
  DEPENDS:=+gluon-core
endef

define Package/$(PKG_NAME)/description
  Package to provide group-based SSH key management
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
