include $(TOPDIR)/rules.mk

PKG_NAME:=gluon-mesh-vpn-wireguard-vxlan
PKG_VERSION:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(TOPDIR)/../package/gluon.mk

define Package/gluon-mesh-vpn-wireguard-vxlan
	SECTION:=gluon
	CATEGORY:=Gluon
	TITLE:=Support for connecting meshes via wireguard
	DEPENDS:=+gluon-mesh-vpn-core +gluon-config-mode-core +micrond +kmod-wireguard +wireguard-tools +ip-full
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
	$(call GluonBuildI18N,gluon-mesh-vpn-wireguard-vxlan,i18n)
endef

define Package/gluon-mesh-vpn-wireguard-vxlan/install
	$(CP) ./files/* $(1)/
	$(call GluonInstallI18N,gluon-mesh-vpn-wireguard-vxlan,$(1))
endef

define Package/gluon-mesh-vpn-wireguard-vxlan/postinst
endef

$(eval $(call BuildPackage,gluon-mesh-vpn-wireguard-vxlan))
