include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-config-mode-at-runtime
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-config-mode-at-runtime
	SECTION:=admin
	CATEGORY:=Administration
	TITLE:=ffgraz-config-mode-at-runtime
endef

define Package/ffgraz-config-mode-at-runtime/description
	Enable config mode server on port 81 during runtime
endef

$(eval $(call BuildPackageGluon,ffgraz-config-mode-at-runtime))
