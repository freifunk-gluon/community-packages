include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-private-net
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-private-net
  TITLE:=A private network of the node's own, behind the mesh
  DEPENDS:=+gluon-core +luci-lib-ip +ffgraz-l3routes +uradvd
endef

define Package/ffgraz-private-net/description
  The bridge, addresses, DHCP and firewall for a private network on the
  interfaces gluon gave the private role. It needs no wifi; ffgraz-private-ap
  adds an access point onto it where there is a radio.
endef

$(eval $(call BuildPackageGluon,ffgraz-private-net))
