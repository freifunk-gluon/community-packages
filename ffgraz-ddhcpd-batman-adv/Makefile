include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-ddhcpd-batman-adv
PKG_VERSION:=2019-11-01
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-ddhcpd-batman-adv
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+micrond +ffgraz-ddhcpd
	TITLE:=ddhcpd batman-adv integration
endef

define Package/ffgraz-ddhcpd-batman-adv/description
  batman-adv integration for ddhcpd
endef

define Package/ffgraz-ddhcpd-batman-adv/install
	$(call Gluon/Build/Install,$(1))
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,ffgraz-ddhcpd-batman-adv))
