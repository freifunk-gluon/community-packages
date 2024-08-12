# SPDX-FileCopyrightText: 2024 Felix Baumann, Florian Maurer (FFAC)
# SPDX-License-Identifier: MIT
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-mt7915-hotfix
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=MIT

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  SECTION:=gluon
  CATEGORY:=Gluon
  TITLE:=reboot device if mt7915e driver shows known failure symptom
  DEPENDS:=@(TARGET_mediatek_filogic||TARGET_ramips_mt7621||TARGET_mediatek_mt7622) kmod-mt7915e +gluon-core +micrond
  MAINTAINER:=Freifunk Aachen <kontakt@freifunk-aachen.de>
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
