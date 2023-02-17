include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-setup-wifi
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-setup-wifi
  TITLE:=Provides a wifi network to connect to webinterface during config-mode
  DEPENDS:=+gluon-core
endef

$(eval $(call BuildPackageGluon,ffgraz-setup-wifi))

