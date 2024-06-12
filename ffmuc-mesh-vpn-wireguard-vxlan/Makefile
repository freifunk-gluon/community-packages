include $(TOPDIR)/rules.mk

PKG_NAME:=ffmuc-mesh-vpn-wireguard-vxlan
PKG_VERSION:=2
PKG_RELEASE:=1

PKG_MAINTAINER:=Annika Wickert <aw@awlnx.space>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/ffmuc-mesh-vpn-wireguard-vxlan
  TITLE:=Support for connecting meshes via wireguard
  DEPENDS:=+gluon-mesh-vpn-core +micrond +kmod-wireguard +wireguard-tools +ip-full +lua-jsonc
endef

define ShSrcDiet
	rm -rf $(2)
	$(CP) $(1) $(2)
  ifdef CONFIG_GLUON_MINIFY
	set -e; $(FIND) $(2) -type f | while read src; do \
		echo "Minifying $$$$src..."; \
		./shell_minify.sh "$$$$src"; \
	done
  endif
endef

define Build/Compile
	$(call Gluon/Build/Compile)
	$(if $(wildcard ./shsrc/.),
		$(call ShSrcDiet,shsrc,$(PKG_BUILD_DIR)/shdest/)
	)
endef

define Package/$(PKG_NAME)/install
	$(Gluon/Build/Install)

	$(if $(wildcard ./shsrc/.),
		$(CP) $(PKG_BUILD_DIR)/shdest/. $(1)/
	)
endef

$(eval $(call BuildPackageGluon,ffmuc-mesh-vpn-wireguard-vxlan))
