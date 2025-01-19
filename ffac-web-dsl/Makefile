include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-web-dsl
PKG_VERSION:=1
PKG_RELEASE:=1

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=gluon-web module to configure ffac-dsl
  DEPENDS:=+gluon-web-admin +ffac-dsl
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
