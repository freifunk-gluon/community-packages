include $(TOPDIR)/rules.mk

PKG_NAME:=ffda-mesh-vpn-fastd-sqm
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/ffda-mesh-vpn-fastd-sqm
  TITLE:=Enable SQM instead of simple-tc on fastd mesh vpn interface
  DEPENDS:=+gluon-mesh-vpn-fastd +sqm-scripts
endef

define Package/ffda-mesh-vpn-fastd-sqm/description
  Enable SQM instead of simple-tc on fastd mesh vpn interface
endef

$(eval $(call BuildPackageGluon,ffda-mesh-vpn-fastd-sqm))
