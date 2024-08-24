include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-wireless-rate-limiter
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL=https://github.com/blocktrron/wireless-rate-limiter.git
PKG_SOURCE_DATE:=2024-08-24
PKG_SOURCE_VERSION:=1fedb08ba7ce347d5c3f7c8ddcac8a5e2f5d14b6

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0

include $(TOPDIR)/../package/gluon.mk
include $(INCLUDE_DIR)/cmake.mk

CMAKE_SOURCE_SUBDIR:=src

define Package/ffda-wireless-rate-limiter
  TITLE:=Wireless rate-limiter
  DEPENDS:=+libubox +libubus +libblobmsg-json +tc +kmod-sched-core +kmod-ifb +gluon-core
endef

define Package/ffda-wireless-rate-limiter/description
  Package to impose per-interface and per-client rate limits on a wireless interface
endef

define Package/ffda-wireless-rate-limiter/conffiles
/etc/config/wireless-rate-limiter
endef

define Package/ffda-wireless-rate-limiter/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/etc/init.d $(1)/etc/config $(1)/lib/wireless-rate-limiter $(1)/lib/gluon/upgrade

	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wireless-rate-limiter $(1)/usr/bin/wireless-rate-limiter

	$(INSTALL_BIN) $(PKG_BUILD_DIR)/openwrt/wireless-rate-limiter/files/wireless-rate-limiter.init $(1)/etc/init.d/wireless-rate-limiter

	$(CP) $(PKG_BUILD_DIR)/openwrt/wireless-rate-limiter/files/wireless-rate-limiter.uci $(1)/etc/config/wireless-rate-limiter

	$(CP) $(PKG_BUILD_DIR)/openwrt/wireless-rate-limiter/files/htb-shared.sh $(1)/lib/wireless-rate-limiter/htb-shared.sh
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/openwrt/wireless-rate-limiter/files/htb-client.sh $(1)/lib/wireless-rate-limiter/htb-client.sh
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/openwrt/wireless-rate-limiter/files/htb-netdev.sh $(1)/lib/wireless-rate-limiter/htb-netdev.sh

	$(INSTALL_BIN) ./files/wireless-rate-limiter.upgrade.lua $(1)/lib/gluon/upgrade/880-wireless-rate-limiter
endef

$(eval $(call BuildPackageGluon,ffda-wireless-rate-limiter))
