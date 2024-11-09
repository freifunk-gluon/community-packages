include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-node-whisperer
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL=https://github.com/blocktrron/node-whisperer.git
PKG_SOURCE_DATE:=2024-11-09
PKG_SOURCE_VERSION:=8f1e5560ce2e9319083004af4b6bfd87e4d246b3

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

MAKE_PATH:=src
MAKE_VARS += \
	NL_LIB="libnl-tiny" \
	NL_GENL_LIB="libnl-tiny"

Build/Compile=$(call Build/Compile/Default)

define Package/ffda-node-whisperer
  TITLE:=Package to provide diagnostic information using WiFi beacons
  DEPENDS:=+gluon-core +libubox +libubus +libblobmsg-json +libnl-tiny +libbatadv +libgluonutil
endef

define Package/ffda-node-whisperer/description
  Package to provide diagnostic information using WiFi beacons
endef

define Package/ffda-node-whisperer/conffiles
/etc/config/node-whisperer
endef

define Package/ffda-node-whisperer/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/etc/init.d $(1)/etc/config $(1)/lib/gluon/upgrade
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/node-whisperer $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/openwrt/node-whisperer/files/node-whisperer.init $(1)/etc/init.d/node-whisperer
	$(CP) $(PKG_BUILD_DIR)/openwrt/node-whisperer/files/node-whisperer.uci $(1)/etc/config/node-whisperer
	$(INSTALL_BIN) ./files/node-whisperer.upgrade.lua $(1)/lib/gluon/upgrade/150-node-whisperer
endef

$(eval $(call BuildPackageGluon,ffda-node-whisperer))
