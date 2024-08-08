include $(TOPDIR)/rules.mk

PKG_NAME:=ffh-check-connection
PKG_VERSION:=1
PKG_RELEASE:=1

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Helper script to do ping checks with configurable IPv6 targets
  DEPENDS:=+gluon-core +libgluonutil +gluon-site +luaposix +luabitop +micrond @GLUON_MULTIDOMAIN
endef

define Package/$(PKG_NAME)/description
  Script to check when there is connectivity to configurable targets
  possible using ICMP IPv6 pings. This script will be executed every
  minute by ``micrond``. If e.g. the connection state changes it
  executes corresponding commands in a configurable manner.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
