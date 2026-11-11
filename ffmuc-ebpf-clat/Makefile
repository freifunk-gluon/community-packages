include $(TOPDIR)/rules.mk

PKG_NAME:=ffmuc-ebpf-clat
PKG_VERSION:=1
PKG_RELEASE:=1
PKG_LICENSE:=LGPL-2.1 OR BSD-2-Clause

include $(TOPDIR)/../package/gluon.mk

# TODO: Update Depends
define Package/$(PKG_NAME)
  TITLE:=eBPF-based CLAT binary (NAT46)
  DEPENDS:=+libbpf
  EXTRA_DEPENDS:=kmod-sched-bpf
endef

MAKE_FLAGS+= \
       OUTPUT=$(PKG_BUILD_DIR)/build \
       CLANG=$(firstword $(shell command -v clang clang-1{3..9} clang-2{0..9})) \
       BPFTOOL=$(shell command -v bpftool) \
       CLAT_INCLUDES="-I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/include" \
       CLANG_INCLUDES="-I$(TOOLCHAIN_DIR)/include -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/include" \
       APPS=clat

define Build/Compile
	$(call Build/Compile/Default,)
endef

define Package/$(PKG_NAME)/install
	$(Gluon/Build/Install)
	$(INSTALL_DIR) $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/clat $(1)/usr/sbin/ebpf-clat
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
