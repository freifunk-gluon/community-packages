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
  EXTRA_DEPENDS:=kmod-sched-bpf (>=6.12)
endef

# The BPF backend needs clang >= 20 (version check in src/Makefile).
# Pick the newest installed clang, and let the builder override with
# make CLANG=/path/to/clang. Brace ranges like clang-2{0..9} never
# expand inside $(shell ...) with /bin/sh, so list the candidates.
CLANG ?= $(firstword $(foreach c,\
	clang-29 clang-28 clang-27 clang-26 clang-25 clang-24 \
	clang-23 clang-22 clang-21 clang-20 clang,\
	$(shell command -v $(c))))

MAKE_FLAGS+= \
       OUTPUT=$(PKG_BUILD_DIR)/build \
       CLANG=$(CLANG) \
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
