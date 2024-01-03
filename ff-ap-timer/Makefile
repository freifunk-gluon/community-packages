include $(TOPDIR)/rules.mk

PKG_NAME:=ffho-ap-timer
PKG_VERSION:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(TOPDIR)/../package/gluon.mk

define Package/ffho-ap-timer
  SECTION:=ffho
  CATEGORY:=FFHO
  TITLE:=Timer for the client wifi
  DEPENDS:=+gluon-core
  MAINTAINER:=Freifunk Hochstift <kontakt@hochstift.freifunk.net>
endef

define Package/ffho-ap-timer/description
	Timer for the client wifi
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
