include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-signed-request
PKG_VERSION:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-signed-request
  TITLE:=ECDSA signed request fetching
  DEPENDS:=+luci-lib-httpclient +lua-ecdsa
endef

define Package/ffgraz-signed-request/install
	$(Gluon/Build/Install)
endef

$(eval $(call BuildPackageGluon,ffgraz-signed-request))
