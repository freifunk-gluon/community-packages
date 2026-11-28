# SPDX-License-Identifier: MIT
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-ap325-no-reset-wipe
PKG_VERSION:=1
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Prevent APBoot factory reset wipe on Aruba AP-32x
  DEPENDS:=+gluon-core
endef

define Package/$(PKG_NAME)/description
  Holding the reset button during boot makes APBoot on the Aruba AP-32x
  run factory_reset: both software images and the U-Boot environment are
  erased before any OS starts. That collides with the usual Gluon habit
  of a long reset button press for config mode and hard-bricks the node.

  APBoot skips the wipe when the U-Boot environment variable
  disable_reset_button is set to "yes" (checked at runtime in
  execute_config_clear), so this package sets exactly that variable once
  on first start and after gluon-reconfigure. The upstream bootloader
  fix (removing CONFIG_RESET_BUTTON entirely) makes this moot for newly
  flashed APBoots, but every running device still needs the environment
  variable.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
