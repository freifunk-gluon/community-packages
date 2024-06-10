include $(TOPDIR)/rules.mk

PKG_NAME:=ffgraz-ddhcpd
PKG_VERSION:=2019-11-02
PKG_RELEASE:=1

PKG_MAINTAINER:=Maciej Krüger <maciej@xeredo.it>
PKG_LICENSE:=MIT

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/ffgraz/ddhcpd
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=345ed5816d62d49dd06a9773d49ca1d000c61e43
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz

PKG_BUILD_PARALLEL:=1

TARGET_CFLAGS += -DLOG_LEVEL_LIMIT=5

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+libnl-tiny
	TITLE:=ddhcpd
endef

define Package/$(PKG_NAME)/description
	distributed dhcp server
endef

define Build/Compile
	$(call Gluon/Build/Compile)
	CFLAGS="$(TARGET_CFLAGS)" LIBNL_NAME=libnl-tiny BUILD_DIR="$(BUILD_DIR)" $(MAKE) -C $(PKG_BUILD_DIR) $(TARGET_CONFIGURE_OPTS)
endef

define Package/$(PKG_NAME)/install
	$(call Gluon/Build/Install,$(1))
	$(INSTALL_DIR) $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ddhcpd  $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ddhcpdctl $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
