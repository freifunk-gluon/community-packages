include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-ddhcpd-olsrd
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-ddhcpd-olsrd
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+ffgraz-ddhcpd +gluon-mesh-olsrd
	TITLE:=ddhcpd olsrd integration
endef

define Package/ffgraz-ddhcpd-olsrd/description
  olsrd integration for ddhcpd
endef

$(eval $(call BuildPackageGluon,ffgraz-ddhcpd-olsrd))

