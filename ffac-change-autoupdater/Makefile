# SPDX-FileCopyrightText: 2023 Florian Maurer (FFAC)
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-change-autoupdater
PKG_VERSION:=1
PKG_LICENSE:=BSD-2-Clause

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  SECTION:=gluon
  CATEGORY:=Gluon
  TITLE:=Migration script to switch autoupdater on nodes from a branch to a different branch
  DEPENDS:=+gluon-core
  MAINTAINER:=Freifunk Aachen <technik@freifunk-aachen.de>
endef

define Package/$(PKG_NAME)/description
	Migration script to switch autoupdater on nodes from a branch to a different branch
endef

define Package/$(PKG_NAME)/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
