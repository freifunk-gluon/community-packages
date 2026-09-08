include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-l3routes-babel
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-l3routes-babel
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+ffgraz-l3routes +gluon-mesh-babel
	TITLE:=Announce l3routes prefixes through babeld
endef

$(eval $(call BuildPackageGluon,ffgraz-l3routes-babel))
