include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-mesh-vpn-openvpn
PKG_VERSION:=3

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-mesh-vpn-openvpn
  TITLE:=Support for connecting meshes via custom openvpn configuration
  DEPENDS:=+gluon-core +gluon-mesh-vpn-core +openvpn +lua-openssl
endef

$(eval $(call BuildPackageGluon,ffgraz-mesh-vpn-openvpn))
