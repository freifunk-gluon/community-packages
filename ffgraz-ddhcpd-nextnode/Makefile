include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-ddhcpd-nextnode
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+ffgraz-ddhcpd
	TITLE:=ddhcpd nextnode integration
endef

define Package/$(PKG_NAME)/description
  nextnode integration for ddhcpd
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))

