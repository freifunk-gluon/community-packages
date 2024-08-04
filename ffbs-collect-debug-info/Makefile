include $(TOPDIR)/rules.mk

PKG_NAME:=ffbs-collect-debug-info
PKG_VERSION:=1

PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/ffbs-collect-debug-info
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Utility script to collect various debug informations for debugging
  DEPENDS:=
endef

define Package/ffbs-collect-debug-info/description
  collect-debug-info can be used by end users to dump various informations
  from a running device. These can be sent to the developers to debug
  or provice support for node specific problems without gaining access to
  the target device.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/ffbs-collect-debug-info/install
	mkdir -p $(1)/usr/bin/
	$(CP) src/collect-debug-info $(1)/usr/bin/
endef

$(eval $(call BuildPackage,ffbs-collect-debug-info))

