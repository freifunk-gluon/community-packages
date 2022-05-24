include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-web-static-ip

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-web-static-ip
  DEPENDS:=+gluon-web-admin +ffgraz-static-ip
  TITLE:=UI for managing static IPs
endef

$(eval $(call BuildPackageGluon,ffgraz-web-static-ip))
