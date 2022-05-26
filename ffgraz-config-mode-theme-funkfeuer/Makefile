# Copyright (C) 2021 Maciej Krüger <maciej at xeredo.it>
# This is free software, licensed under the Apache 2.0 license.

include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-config-mode-theme-funkfeuer
PKG_VERSION:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

include $(TOPDIR)/../package/gluon.mk

define Package/ffgraz-config-mode-theme-funkfeuer
	TITLE:=Gluon config mode theme for gluon-web customized for funkfeuer
	DEPENDS:=+gluon-core +gluon-web
	PROVIDES:=gluon-config-mode-theme
endef

$(eval $(call BuildPackageGluon,ffgraz-config-mode-theme-funkfeuer))
