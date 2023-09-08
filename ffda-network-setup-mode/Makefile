include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-network-setup-mode
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/ffda-network-setup-mode
  TITLE:=Activate setup-mode using a magic packet
  DEPENDS:=+gluon-core
endef

define Package/ffda-network-setup-mode/install
	$(Gluon/Build/Install)

	$(INSTALL_DIR) $(1)/lib/gluon/setup-mode
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wait-network-request $(1)/lib/gluon/setup-mode
endef

$(eval $(call BuildPackageGluon,ffda-network-setup-mode))
