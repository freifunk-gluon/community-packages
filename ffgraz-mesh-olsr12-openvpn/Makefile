include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-mesh-olsr12-openvpn
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-mesh-olsr12-openvpn
  TITLE:=olsrd v1 to v2 migration fallback vpn
  DEPENDS:= +gluon-mesh-olsrd +openvpn
endef

$(eval $(call BuildPackageGluon,ffgraz-mesh-olsr12-openvpn))
