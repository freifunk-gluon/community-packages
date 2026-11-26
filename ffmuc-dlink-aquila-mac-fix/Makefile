# SPDX-License-Identifier: MIT
include $(TOPDIR)/rules.mk

PKG_NAME:=ffmuc-dlink-aquila-mac-fix
PKG_VERSION:=1
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Reset the broken primary MAC of D-Link AQUILA PRO AI multi-pack units
  DEPENDS:=@TARGET_mediatek_filogic +gluon-core
endef

define Package/$(PKG_NAME)/description
  D-Link AQUILA PRO AI M30 and M60 units from a multi-pack got a broken
  MAC address from older firmware. Gluon keeps the primary MAC across
  upgrades. This package drops a broken one, so that Gluon reads the
  factory address again.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
