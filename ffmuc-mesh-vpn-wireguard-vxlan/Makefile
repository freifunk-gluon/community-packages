include $(TOPDIR)/rules.mk

PKG_NAME:=ffmuc-mesh-vpn-wireguard-vxlan
PKG_VERSION:=2
PKG_RELEASE:=1

PKG_MAINTAINER:=Annika Wickert <aw@awlnx.space>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/ffmuc-mesh-vpn-wireguard-vxlan
  TITLE:=Support for connecting meshes via wireguard
  DEPENDS:=+gluon-mesh-vpn-core +micrond +kmod-wireguard +wireguard-tools +ip-full +lua-jsonc
endef

$(eval $(call BuildPackageGluon,ffmuc-mesh-vpn-wireguard-vxlan))
