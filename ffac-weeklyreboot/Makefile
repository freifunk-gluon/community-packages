# SPDX-FileCopyrightText: 2023 Andreas Dorfer (Eulenfunk)
# SPDX-License-Identifier: BSD-2-Clause
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-weeklyreboot
PKG_VERSION:=2
PKG_RELEASE:=1

PKG_LICENSE:=BSD-2-Clause

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  SECTION:=gluon
  CATEGORY:=Gluon
  TITLE:=weekly reboot sheduled on thursday
  DEPENDS:=+gluon-core +micrond
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(CP) ./files/* $(1)/
	./gluonShellDiet.sh $(1)/lib/gluon/weeklyreboot/weeklyreboot.sh
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
