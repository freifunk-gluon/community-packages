# SPDX-FileCopyrightText: 2023 kb-light, Patric Steffen, Andreas Ziegler, Florian Maurer
# SPDX-License-Identifier: BSD-2-Clause
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-autoupdater-wifi-fallback
PKG_VERSION:=2
PKG_LICENSE:=BSD-2-Clause

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)
PKG_BUILD_DEPENDS := respondd

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Implements switching to fallback mode if we are cut off from the mesh
  DEPENDS:=+gluon-autoupdater +gluon-site +gluon-state-check +iw +libgluonutil +libiwinfo-lua +luabitop +luaposix +micrond +wpa-supplicant-mini
  MAINTAINER:=Freifunk Aachen <kontakt@freifunk-aachen.de>
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
