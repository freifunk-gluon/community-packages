# SPDX-FileCopyrightText: 2023 kb-light, Michael Schwarz, Florian Maurer
# SPDX-License-Identifier: BSD-2-Clause
include $(TOPDIR)/rules.mk

PKG_NAME:=ff-ap-timer
PKG_VERSION:=1
PKG_LICENSE:=BSD-2-Clause

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  SECTION:=gluon
  CATEGORY:=Gluon
  TITLE:=Timer for the client wifi
  DEPENDS:=+gluon-core
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/ap-timer
endef

define Package/$(PKG_NAME)/description
	Allow to turn client wifi on and off on set schedule
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
