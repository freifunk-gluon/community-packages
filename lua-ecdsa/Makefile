include $(TOPDIR)/rules.mk

PKG_NAME:=lua-ecdsa
PKG_VERSION=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=Apache-2.0 BSD-2-Clause

include $(INCLUDE_DIR)/package.mk

define Package/lua-ecdsa
	SECTION:=libs
	CATEGORY:=Libraries
	TITLE:=Lua bindings for ecdsautil
	DEPENDS:=+liblua +libecdsautil
endef

define Package/lua-ecdsa/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ecdsa.so $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,lua-ecdsa))
