include $(TOPDIR)/rules.mk

PKG_NAME:=ddhcpd-batman-adv
PKG_VERSION:=2019-11-01
PKG_RELEASE:=1

include $(TOPDIR)/../package/gluon.mk

define Package/ddhcpd-batman-adv
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+micrond +ddhcpd
	TITLE:=ddhcpd batman-adv integration
endef

define Package/ddhcpd-batman-adv/description
  batman-adv integration for ddhcpd
endef

define Package/ddhcpd-batman-adv/install
	$(call Gluon/Build/Install,$(1))
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,ddhcpd-batman-adv))
