include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-l3routes
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-l3routes
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+gluon-core +luci-lib-ip
	TITLE:=Extra route announcements for the mesh
endef

define Package/ffgraz-l3routes/description
  Collects extra prefixes to announce into the mesh from the drop-in snippets
  in /lib/gluon/l3routes, installs the kernel routes and firewall rules they
  need, and offers them to the mesh protocols through the gluon.l3routes Lua
  module. The announcement itself is done by ffgraz-l3routes-babel and
  ffgraz-l3routes-olsr.
endef

define Package/ffgraz-l3routes/conffiles
/etc/config/gluon-l3routes
endef

$(eval $(call BuildPackageGluon,ffgraz-l3routes))
