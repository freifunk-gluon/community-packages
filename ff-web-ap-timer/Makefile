# SPDX-FileCopyrightText: 2023 kb-light, Michael Schwarz, Florian Maurer
# SPDX-License-Identifier: BSD-2-Clause
include $(TOPDIR)/rules.mk

PKG_NAME:=ff-web-ap-timer
PKG_VERSION:=1
PKG_LICENSE:=BSD-2-Clause

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  SECTION:=gluon
  CATEGORY:=Gluon
  TITLE:=Web module for ap-timer settings
  DEPENDS:=+gluon-web-admin +ff-ap-timer
endef

define Package/$(PKG_NAME)/description
	Gluon-web module for ap-timer settings
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
