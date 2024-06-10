include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-config-mode-at-runtime
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
	SECTION:=admin
	CATEGORY:=Administration
	TITLE:=$(PKG_NAME)
	DEPENDS:= +ffgraz-web-model
endef

define Package/$(PKG_NAME)/description
	Enable config mode server on port 81 during runtime
endef

define Package/$(PKG_NAME)/install
	$(Gluon/Build/Install)

	$(INSTALL_DIR) $(1)/lib/gluon/config-mode-runtime/view/ $(1)/lib/gluon/config-mode-runtime/www/static/
	$(LN) /lib/gluon/web/i18n $(1)/lib/gluon/config-mode-runtime/
	$(LN) /lib/gluon/web/view/{error,model} $(1)/lib/gluon/config-mode-runtime/view/
	$(LN) /lib/gluon/web/www/static/gluon-web-model.js $(1)/lib/gluon/config-mode-runtime/www/static/

	$(LN) /lib/gluon/config-mode/view/{wizard,admin} $(1)/lib/gluon/config-mode-runtime/view/
	$(LN) /lib/gluon/config-mode/controller/admin $(1)/lib/gluon/config-mode-runtime/controller/
	$(LN) /lib/gluon/config-mode/model/admin $(1)/lib/gluon/config-mode-runtime/model/
	$(LN) /lib/gluon/config-mode/www/index.html $(1)/lib/gluon/config-mode-runtime/www/
	$(LN) /lib/gluon/config-mode/www/static/gluon.css $(1)/lib/gluon/config-mode-runtime/www/static/
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
