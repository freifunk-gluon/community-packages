include $(TOPDIR)/rules.mk

PKG_NAME:=ffbs-parker-nextnode
PKG_VERSION:=1

PKG_MAINTAINER:=Chris Fiege <chris@tinyhost.de>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffbs-parker-nextnode
  TITLE:=gluon-nextnode config for parker
endef

define Package/ffbs-parker-nextnode/description
	This package adds ebtables rules for the parker nextnode range.
	This package is needed when the nextnode-ips are outside of the
	local net of the router - what is usually the case for parker networks.
endef

$(eval $(call BuildPackageGluon,ffbs-parker-nextnode))

