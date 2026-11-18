# SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause)
OUTPUT ?= build
CLANG ?= clang
BPFTOOL ?= bpftool
ARCH ?= x86
CLAT_CFLAGS ?= $(CFLAGS) -Wall
CLAT_LDFLAGS ?= $(LDFLAGS)
CLAT_INCLUDES ?=
CLANG_INCLUDES ?= $(CLAT_INCLUDES) -Ivmlinux.h
MIN_CLANG_VERSION ?= 20
APPS ?= clat

# libbpf archs (except mips and arc, due to mixed endianness)
# https://github.com/libbpf/libbpf/blob/58dd1f58b57294b2e59482245b29e46f1812b82d/src/bpf_tracing.h#L8-L38
LIBBPF_ARCHS_EL := x86 arm arm64 riscv loongarch
LIBBPF_ARCHS_EB := s390 sparc powerpc

# Convert compiler archs to libbpf archs (required to convert OpenWRT ARCHs)
# and add BPF target with correct endianness
ifneq ($(filter $(ARCH),$(LIBBPF_ARCHS_EL)),)
	BPF_TARGET_ARCH = $(ARCH)
	BPF_TARGET = bpfel
else ifneq ($(filter $(ARCH),$(LIBBPF_ARCHS_EB)),)
	BPF_TARGET_ARCH = $(ARCH)
	BPF_TARGET = bpfeb
else ifeq ($(ARCH),aarch64)
	BPF_TARGET_ARCH = arm64
	BPF_TARGET = bpfel
else ifeq ($(ARCH),i386)
	BPF_TARGET_ARCH = x86
	BPF_TARGET = bpfel
else ifeq ($(ARCH),x86_64)
	BPF_TARGET_ARCH = x86
	BPF_TARGET = bpfel
else ifeq ($(ARCH),riscv64)
	BPF_TARGET_ARCH = riscv
	BPF_TARGET = bpfel
else ifeq ($(ARCH),powerpc64)
	BPF_TARGET_ARCH = powerpc
	BPF_TARGET = bpfeb
else ifeq ($(ARCH),mips)
	BPF_TARGET_ARCH = mips -D__MIPSEB__
	BPF_TARGET = bpfeb
else ifeq ($(ARCH),mips64)
	BPF_TARGET_ARCH = mips -D__MIPSEB__
	BPF_TARGET = bpfeb
else ifeq ($(ARCH),mipsel)
	BPF_TARGET_ARCH = mips -D__MIPSEL__
	BPF_TARGET = bpfel
else ifeq ($(ARCH),mips64el)
	BPF_TARGET_ARCH = mips -D__MIPSEL__
	BPF_TARGET = bpfel
else
	BPF_TARGET_ARCH = $(error Unsupported ARCH "$(ARCH)". Please implement it in Makefile.)
endif

CLANG_VERSION := $(shell $(CLANG) -dumpversion)
IS_CLANG_NEW_ENOUGH := $(shell expr $(CLANG_VERSION) ">=" $(MIN_CLANG_VERSION))

ifeq ($(IS_CLANG_NEW_ENOUGH),0) # 0 equals "false"
 $(error Found clang $(CLANG_VERSION). Version $(MIN_CLANG_VERSION) or later is required. See https://gist.github.com/DasSkelett/f373dac5692b95b0daae7ebb58fad8d1.)
endif

.PHONY: all
all: $(APPS)

.PHONY: clean
clean:
	$(call msg,CLEAN)
	$(Q)rm -rf $(OUTPUT) $(APPS)

$(OUTPUT):
	$(call msg,MKDIR,$@)
	$(Q)mkdir -p $@

# vmlinux.h should only be generated when running clat the same kernel as the running kernel
# otherwise use kernel-headers for the target system instead
vmlinux.h:
	$(BPFTOOL) btf dump file /sys/kernel/btf/vmlinux format c > $@
	$(warning auto-generated vmlinux.h. Make sure you are running clat with the same kernel as the currently running kernel!)

# Build BPF code
$(OUTPUT)/%.bpf.o: %.bpf.c $(wildcard %.h) | $(OUTPUT)
	$(call msg,BPF,$@)
	$(Q)$(CLANG) -g -O2 -target $(BPF_TARGET) -D__TARGET_ARCH_$(BPF_TARGET_ARCH) -I$(OUTPUT) \
			$(CLANG_INCLUDES) \
			-c $(filter %.c,$^) -o $(patsubst %.bpf.o,%.tmp.bpf.o,$@)
	$(Q)$(BPFTOOL) gen object $@ $(patsubst %.bpf.o,%.tmp.bpf.o,$@)

# Generate BPF skeletons
$(OUTPUT)/%.skel.h: $(OUTPUT)/%.bpf.o | $(OUTPUT)
	$(call msg,GEN-SKEL,$@)
	$(Q)$(BPFTOOL) gen skeleton $< > $@

# Build user-space code
$(patsubst %,$(OUTPUT)/%.o,$(APPS)): %.o: %.skel.h

$(OUTPUT)/%.o: %.c $(wildcard %.h) | $(OUTPUT)
	$(call msg,CC,$@)
	$(Q)$(CC) $(CLAT_CFLAGS) -I$(OUTPUT) -c $(filter %.c,$^) \
			$(CC_INCLUDES) \
			-o $@

# Build application binary
$(APPS): %: $(OUTPUT)/%.o | $(OUTPUT)
	$(call msg,BINARY,$@)
	$(Q)$(CC) $(CLAT_CFLAGS) $^ \
			$(CLAT_LDFLAGS) \
			-lelf -lbpf -lz \
			-o $@

# delete failed targets
.DELETE_ON_ERROR:

# keep intermediate (.skel.h, .bpf.o, etc) targets
.SECONDARY:
