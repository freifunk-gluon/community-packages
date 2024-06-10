include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-web-mesh-vpn-openvpn

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=gluon-web module to upload keys for openvpn mesh-vpn
  DEPENDS:=+gluon-web-admin +ffgraz-web-model +ffgraz-mesh-vpn-openvpn +lua-openssl
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
