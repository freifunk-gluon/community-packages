include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-signed-request
PKG_VERSION:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-signed-request
  TITLE:=ECDSA signed request fetching
  DEPENDS:=+luci-lib-httpclient +lua-ecdsa
endef

define Package/ffgraz-signed-request/install
	$(Gluon/Build/Install)

	# httpclient depends on util depends on template.parser & sys.zoneinfo which is from +luci-base
	# +luci-base is quite big and unnesesarry. stubbing the files is enough to make it work.
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/template
	touch $(1)/usr/lib/lua/luci/template/parser.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/sys
	touch $(1)/usr/lib/lua/luci/sys/zoneinfo.lua
endef

$(eval $(call BuildPackageGluon,ffgraz-signed-request))
