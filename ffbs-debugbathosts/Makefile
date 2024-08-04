include $(TOPDIR)/rules.mk

PKG_NAME:=ffbs-debugbathosts
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_MAINTAINER:=Chris Fiege <chris@tinyhost.de>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Provide /etc/bat-hosts.
endef

define Package/$(PKG_NAME)/description
    This package provides an empty /etc/bat-hosts file.
    It simply serves as a reminder, that this file exists and how
    it can be used.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))

