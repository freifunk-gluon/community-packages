include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-config-mode-remote
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-config-mode-remote
	SECTION:=admin
	CATEGORY:=Administration
	TITLE:=ffgraz-config-mode-remote
	DEPENDS:=+ffgraz-config-mode-at-runtime +ffgraz-signed-request
endef

define Package/ffgraz-config-mode-remote/description
	Allow accessing the config mode remotely via simple token auth
endef

define Package/ffgraz-config-mode-remote/install
	$(Gluon/Build/Install)

	$(INSTALL_DIR) $(1)/lib/gluon/status-page/www/static/ $(1)/lib/gluon/status-page/www/cgi-bin/
	$(LN) /lib/gluon/web/www/static/gluon-web-model.js $(1)/lib/gluon/status-page/www/static/
	$(LN) /lib/gluon/config-mode/www/static/gluon.css $(1)/lib/gluon/status-page/www/static/
	$(LN) /lib/gluon/config-mode-runtime/www/cgi-bin/config $(1)/lib/gluon/status-page/www/cgi-bin/
endef

$(eval $(call BuildPackageGluon,ffgraz-config-mode-remote))
