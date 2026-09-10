include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-config-mode-remote
PKG_RELEASE:=2

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-config-mode-remote
	SECTION:=admin
	CATEGORY:=Administration
	TITLE:=ffgraz-config-mode-remote
	# lua-openssl for verifying the capability - it must be 0.11.1 or newer,
	# which is what the packages feed pins; 0.9.2 has no Ed25519 case and
	# answers "invalid digest" instead of checking the signature.
	# px5g so uhttpd can generate the certificate the proxy pins to, and
	# libustream-ssl because uhttpd loads its TLS provider at runtime - without
	# it listen_https is accepted and then silently never listens.
	DEPENDS:=+ffgraz-config-mode-at-runtime +lua-openssl +px5g-mbedtls \
		+libustream-ssl
endef

define Package/ffgraz-config-mode-remote/description
	Reach a node's config mode through the gluon-provisioning proxy, which
	decides who may open which node and proves it with a signed capability
	naming this node.
endef

define Package/ffgraz-config-mode-remote/install
	$(Gluon/Build/Install)

	$(INSTALL_DIR) $(1)/lib/gluon/status-page/www/static/ $(1)/lib/gluon/status-page/www/cgi-bin/
	$(LN) /lib/gluon/web/www/static/gluon-web-model.js $(1)/lib/gluon/status-page/www/static/
	$(LN) /lib/gluon/config-mode/www/static/gluon.css $(1)/lib/gluon/status-page/www/static/
	$(LN) /lib/gluon/config-mode-runtime/www/cgi-bin/config $(1)/lib/gluon/status-page/www/cgi-bin/
endef

$(eval $(call BuildPackageGluon,ffgraz-config-mode-remote))
