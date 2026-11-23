include $(TOPDIR)/rules.mk

PKG_NAME:=ff3l-badblocks-disable-autoupdater
PKG_VERSION:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include ../../../package/gluon.mk

define Package/ff3l-badblocks-disable-autoupdater
  SECTION:=gluon
  CATEGORY:=Gluon
  TITLE:=Disable autoupdater if device has bad eraseblocks
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
	$(call GluonSrcDiet,./luasrc,$(PKG_BUILD_DIR)/luadest/)
endef

define Package/ff3l-badblocks-disable-autoupdater/install
	$(CP) $(PKG_BUILD_DIR)/luadest/* $(1)/
endef

$(eval $(call BuildPackage,ff3l-badblocks-disable-autoupdater))