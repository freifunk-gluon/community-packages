include $(TOPDIR)/rules.mk

PKG_NAME:=ff-mesh-vpn-parker-migrate
PKG_VERSION:=1
PKG_RELEASE:=1
PKG_LICENSE:=BSD-2-Clause

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Migrate a node from mesh-vpn-wireguard-vxlan to Parker
  DEPENDS:=+gluon-core +ffbs-mesh-vpn-parker
endef

define Package/$(PKG_NAME)/description
	Moves the WireGuard key of ffmuc-mesh-vpn-wireguard-vxlan to Parker.
	With this package, a node can go from a WireGuard/VXLAN firmware to a
	Parker firmware with a normal sysupgrade or autoupdater run.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
