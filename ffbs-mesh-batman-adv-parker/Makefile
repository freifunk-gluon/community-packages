include $(TOPDIR)/rules.mk

PKG_NAME:=ffbs-mesh-batman-adv-parker
PKG_VERSION:=1

PKG_MAINTAINER:=Florian Maurer <fmaurer@disroot.org>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffbs-mesh-batman-adv-parker
  TITLE:=batman-adv mesh with a router on every parker node
  DEPENDS:=+gluon-mesh-batman-adv-common +gluon-radvd +gluon-radv-filterd +ffbs-mesh-vpn-parker
  CONFLICTS:=gluon-mesh-batman-adv-15
endef

define Package/ffbs-mesh-batman-adv-parker/description
  batman-adv mesh for parker networks, in place of gluon-mesh-batman-adv-15.
  Every node with a tunnel is the default router of its clients and of the
  nodes meshed behind it, with its own prefix.
endef

$(eval $(call BuildPackageGluon,ffbs-mesh-batman-adv-parker))
