include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-web-static-ip

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  DEPENDS:=+gluon-web-admin +ffgraz-web-model +ffgraz-static-ip
  TITLE:=UI for managing static IPs
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
