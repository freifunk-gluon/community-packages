include $(TOPDIR)/rules.mk

PKG_NAME:=ffbs-mesh-vpn-parker
PKG_VERSION:=1

PKG_MAINTAINER:=Chris Fiege <chris@tinyhost.de>
PKG_LICENSE:=MIT

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(TOPDIR)/../package/gluon.mk

define Package/ffbs-mesh-vpn-parker
  TITLE:=Automatic node configuration for parker networks
  DEPENDS:=+gluon-core +libgluonutil +gluon-mesh-vpn-core +kmod-wireguard +wireguard-tools +luaposix +usign +gluon-radv-filterd +gluon-ebtables-filter-ra-dhcp +ffbs-parker-nextnode +ffbs-parker-nodeconfig-respondd
  PROVIDES:=ffbs-parker-nodeconfig
endef

define Package/ffbs-mesh-vpn-parker/description
  This package is the central component for parker-based network.
  It downloads a configuration for a node.
  It keeps track of the node's connectivity and changes the state as needed.
endef

$(eval $(call BuildPackageGluon,ffbs-mesh-vpn-parker))

