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
  This package provides an empty /etc/bat-hosts file and the script
  update-bat-hosts that populates /etc/bat-hosts with entries from
  a given nodes.json.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))

