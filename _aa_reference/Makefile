# 本目录保存自有实验文件；O= 将所有构建产物放在 build/。
.DEFAULT_GOAL := help
SHELL := /bin/bash
REF_DIR := $(abspath .)
SOURCE := $(abspath $(REF_DIR)/..)
OUTPUT := $(REF_DIR)/build
ENV := bash $(REF_DIR)/with-env.sh
JOBS ?= 16
GDB_PORT ?= 1235
BUSYBOX ?= $(REF_DIR)/.tools/usr/bin/busybox
# 上游基线已由 check-source 核验；显式给出空 LOCALVERSION，避免 setlocalversion
# 每次增量构建都扫描整个 Git 工作区。实验后缀仍由 config.fragment 提供。
KMAKE := $(ENV) $(MAKE) -C $(SOURCE) O=$(OUTPUT) ARCH=x86_64 LOCALVERSION=
QEMU := qemu-system-x86_64
QEMU_ARGS := -machine q35 -accel tcg -cpu qemu64 -m 512M -smp 1 \
	-display none -serial stdio -monitor none -nic none -no-reboot \
	-kernel $(OUTPUT)/arch/x86/boot/bzImage -initrd $(OUTPUT)/initramfs.cpio
CMDLINE := console=ttyS0,115200 nokaslr rdinit=/init panic=-1

.PHONY: help check-source configure build initramfs run debug gdb test test-debug
help:
	@echo 'make build     构建固定版本的 bzImage 与带调试信息的 vmlinux'
	@echo 'make run       启动串口 BusyBox shell；poweroff -f 退出'
	@echo 'make debug     启动 QEMU 并在复位处等待 GDB（127.0.0.1:1235）'
	@echo 'make gdb       另一终端连接并停在 start_kernel'
	@echo 'make test      自动验证启动到 PID 1 后正常关机'
	@echo 'make test-debug 自动验证 GDB 命中 start_kernel，并继续到 PID 1 关机'

# HEAD 可以包含本目录的实验提交；其余已提交源码必须仍等于上游基线。
check-source:
	@set -e; expected=$$(cat upstream.commit); \
	actual=$$($(ENV) git -C $(SOURCE) rev-parse 'v6.18.54^{commit}'); \
	test "$$actual" = "$$expected"; \
	$(ENV) git -C $(SOURCE) merge-base --is-ancestor "$$expected" HEAD; \
	$(ENV) git -C $(SOURCE) diff --quiet "$$expected" HEAD -- . ':(exclude)_aa_reference' || \
	{ echo '上游基线之外的提交只能修改 _aa_reference/ 实验文件'; exit 1; }

$(OUTPUT)/.config: config.fragment | check-source
	@mkdir -p $(OUTPUT)
	$(KMAKE) x86_64_defconfig
	$(ENV) bash $(SOURCE)/scripts/kconfig/merge_config.sh -m -O $(OUTPUT) $(OUTPUT)/.config config.fragment
	$(KMAKE) olddefconfig

configure: $(OUTPUT)/.config

build: check-source $(OUTPUT)/.config
	$(KMAKE) -j$(JOBS) bzImage

initramfs: build init
	@test -f $(BUSYBOX) || { echo '请设置 BUSYBOX=/path/to/static-busybox'; exit 1; }
	@{ \
		printf 'dir /bin 755 0 0\ndir /dev 755 0 0\ndir /proc 755 0 0\ndir /sys 755 0 0\ndir /tmp 1777 0 0\n'; \
		printf 'file /bin/busybox %s 755 0 0\n' $(BUSYBOX); \
		printf 'slink /bin/sh busybox 777 0 0\nfile /init %s 755 0 0\n' $(REF_DIR)/init; \
		printf 'nod /dev/console 600 0 0 c 5 1\nnod /dev/null 666 0 0 c 1 3\n'; \
	} > $(OUTPUT)/initramfs.list
	$(OUTPUT)/usr/gen_init_cpio $(OUTPUT)/initramfs.list > $(OUTPUT)/initramfs.cpio

run: initramfs
	$(QEMU) $(QEMU_ARGS) -append '$(CMDLINE)'

debug: initramfs
	$(QEMU) $(QEMU_ARGS) -append '$(CMDLINE)' -S -gdb tcp:127.0.0.1:$(GDB_PORT)

# gdb 脚本按 _aa_reference/ 为工作目录；端口只绑定本机回环地址。
gdb: check-source
	gdb -nx -q -ex 'set auto-load python-scripts off' -ex 'file build/vmlinux' \
		-ex 'target remote 127.0.0.1:$(GDB_PORT)' -x debug/start.gdb

test: initramfs
	@timeout 90 $(QEMU) $(QEMU_ARGS) -append '$(CMDLINE) aa_ref_test=1' > $(OUTPUT)/boot-test.log 2>&1
	@grep -F '[PASS] linux-reference userspace pid=1' $(OUTPUT)/boot-test.log
	@grep -F 'Power down' $(OUTPUT)/boot-test.log

test-debug: initramfs
	python3 debug/test.py $(GDB_PORT) $(QEMU) $(QEMU_ARGS) -append '$(CMDLINE) aa_ref_test=1'
