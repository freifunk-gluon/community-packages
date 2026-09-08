include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-extra-networks
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-extra-networks
  TITLE:=The node's own networks alongside the mesh
  DEPENDS:=+gluon-core +luci-lib-ip +ffgraz-l3routes +uradvd
endef

define Package/ffgraz-extra-networks/description
  The bridges, addresses, DHCP and firewall for the networks the node carries
  besides the mesh: a private one behind it, and an exposed one the mesh
  reaches directly. Neither needs wifi; ffgraz-private-ap adds an access point
  onto the private one where there is a radio.
endef

$(eval $(call BuildPackageGluon,ffgraz-extra-networks))
