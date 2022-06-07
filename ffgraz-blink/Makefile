include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-blink
PKG_VERSION:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-blink
  TITLE:=Adds the gluon-blink command to make your current device blink
  DEPENDS:=+gluon-core
endef

$(eval $(call BuildPackageGluon,ffgraz-blink))
