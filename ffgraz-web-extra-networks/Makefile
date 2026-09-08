include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-web-extra-networks
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-web-extra-networks
  DEPENDS:=+gluon-web-admin +ffgraz-extra-networks +luci-lib-ip
  TITLE:=Settings for the node's own network ranges
endef

$(eval $(call BuildPackageGluon,ffgraz-web-extra-networks))
