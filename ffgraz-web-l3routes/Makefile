include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-web-l3routes
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-web-l3routes
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+gluon-web-admin +ffgraz-l3routes
	TITLE:=Config mode page for extra route announcements
endef

define Package/ffgraz-web-l3routes/conffiles
/etc/config/gluon-l3routes-custom
endef

$(eval $(call BuildPackageGluon,ffgraz-web-l3routes))
