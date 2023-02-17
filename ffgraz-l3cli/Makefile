include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-l3cli
PKG_VERSION:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-l3cli
  TITLE:=Adds the gluon-l3cli command to talk to l3roamd
  DEPENDS:=+gluon-core
endef

$(eval $(call BuildPackageGluon,ffgraz-l3cli))

