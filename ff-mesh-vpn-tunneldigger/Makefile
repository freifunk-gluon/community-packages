include $(TOPDIR)/rules.mk

PKG_NAME:=ff-mesh-vpn-tunneldigger
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

PKG_LICENSE:=BSD-2-Clause

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Support for connecting meshes via tunneldigger/L2TPv3 pseudowire
  DEPENDS:=+gluon-core +gluon-mesh-vpn-core +tunneldigger +simple-tc
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
