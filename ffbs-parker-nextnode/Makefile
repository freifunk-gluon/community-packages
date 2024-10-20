include $(TOPDIR)/rules.mk

PKG_NAME:=ffbs-parker-nextnode
PKG_VERSION:=1

PKG_MAINTAINER:=Chris Fiege <chris@tinyhost.de>
PKG_LICENSE:=MIT

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/ffbs-parker-nextnode
  TITLE:=gluon-nextnode config for parker
  DEPENDS:=+ffbs-parker-nodeconfig
endef

define Package/ffbs-parker-nextnode/description
	This package adds ebtables rules for the parker nextnode range.
	This package is needed when the nextnode-ips are outside of the
	local net of the router - what is usually the case for parker networks.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/ffbs-parker-nextnode/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,ffbs-parker-nextnode))

