include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-l3routes-olsr
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-l3routes-olsr
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+ffgraz-l3routes +gluon-mesh-olsrd
	TITLE:=Announce l3routes prefixes as olsr HNAs
endef

$(eval $(call BuildPackageGluon,ffgraz-l3routes-olsr))
