
KDIR      ?= $(HOME)/OSS/common
WORKSPACE ?= $(HOME)/OSS
ARCH      := arm64

obj-m := overclock_mt6789.o

CLANG_PREBUILT_BIN := $(shell \
  grep -E "^CLANG_PREBUILT_BIN=" $(WORKSPACE)/common/build.config.common \
  2>/dev/null | cut -d= -f2 | head -1)

ifneq ($(CLANG_PREBUILT_BIN),)
  CLANG_PATH := $(WORKSPACE)/$(CLANG_PREBUILT_BIN)
else
  CLANG_PATH := $(shell ls -d $(WORKSPACE)/prebuilts/clang/host/linux-x86/clang-r*/bin \
    2>/dev/null | sort -V | tail -1)
endif

ifeq ($(CLANG_PATH),)
  $(error Clang not found under GKI prebuilts — check WORKSPACE ($(WORKSPACE)) and repo sync)
endif

CC            := $(CLANG_PATH)/clang
CLANG_TRIPLE  := aarch64-linux-gnu-
CROSS_COMPILE := aarch64-linux-gnu-
LLVM          := 1

EXTRA_CFLAGS  := \
  --target=aarch64-linux-gnu \
  -fno-sanitize=shadow-call-stack \
  -Wno-unused-variable \
  -Wno-unused-function \
  -Wno-int-to-pointer-cast \
  -Wno-pointer-to-int-cast \
  -Wno-unused-command-line-argument

all:
	@echo "  [overclock_mt6789] Using Clang: $(CLANG_PATH)/clang"
	@$(CLANG_PATH)/clang --version 2>/dev/null | head -1
	$(MAKE) -C $(KDIR) M=$(CURDIR) \
	  ARCH=$(ARCH) \
	  CC=$(CC) \
	  CLANG_TRIPLE=$(CLANG_TRIPLE) \
	  CROSS_COMPILE=$(CROSS_COMPILE) \
	  LLVM=1 \
	  LLVM_IAS=1 \
	  EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
	  modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean

install:
	adb push overclock_mt6789.ko /data/local/tmp/
	adb shell su -c "insmod /data/local/tmp/overclock_mt6789.ko"
	@sleep 1
	adb shell su -c "dmesg | grep oc_mt6789 | tail -20"

uninstall:
	adb shell su -c "rmmod overclock_mt6789 && echo OK"

check-clang:
	@echo "WORKSPACE    : $(WORKSPACE)"
	@echo "CLANG_PATH   : $(CLANG_PATH)"
	@echo "Clang version: $$($(CLANG_PATH)/clang --version 2>/dev/null | head -1)"
	@echo "KDIR         : $(KDIR)"
