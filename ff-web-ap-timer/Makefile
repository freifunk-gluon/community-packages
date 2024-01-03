include $(TOPDIR)/rules.mk

PKG_NAME:=ffho-web-ap-timer
PKG_VERSION:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(TOPDIR)/../package/gluon.mk

define Package/ffho-web-ap-timer
  SECTION:=ffho
  CATEGORY:=FFHO
  TITLE:=Luci module for ap-timer settings
  DEPENDS:=+gluon-web-admin
  MAINTAINER:=Freifunk Hochstift <kontakt@hochstift.freifunk.net>
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
