# SPDX-License-Identifier: MIT
include $(TOPDIR)/rules.mk

PKG_NAME:=ffmuc-leds-off
PKG_VERSION:=1
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Disable all LEDs during normal operation
  DEPENDS:=+gluon-core
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/leds-off
endef

define Package/$(PKG_NAME)/description
  Darkens all LEDs after the boot sequence completes (S99, after
  set_state done at S95). Intended for nodes deployed in dark
  environments or where visible LEDs would expose the device to
  onlookers. LEDs follow their normal patterns during preinit, boot,
  sysupgrade, and setup mode so error and progress signals stay
  debuggable. Disabled by default; enable per-node with
  `uci set leds-off.settings.enabled='1' && gluon-reconfigure`.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
