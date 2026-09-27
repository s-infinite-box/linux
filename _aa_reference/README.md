# Linux 6.18 本地对照实验

以下命令默认从本 Linux 仓库根目录执行。本实验可独立运行，无需依赖 aa 项目。

## 1. 文件布局

```text
_aa_reference/
├── upstream.commit      # 原始 Linux v6.18.54 的固定提交
├── build/               # O= 构建目录、initramfs 与实验日志，忽略提交
├── .tools/              # 本机可选构建依赖和静态 BusyBox，忽略提交
├── config.fragment      # 在 x86_64_defconfig 上叠加的实验配置
├── init                 # 现代 Linux 客户机内的 PID 1 脚本
├── Makefile             # build/run/debug/gdb/test 入口
├── with-env.sh          # 仅对实验子进程设置本地依赖环境
├── prepare-tools.sh     # Fedora 可选依赖下载/解包流程
└── debug/start.gdb      # 停在 start_kernel 的 GDB 脚本
```

仓库根目录保存上游 Linux 源码，自有文件集中放在 `_aa_reference/` 中；`build/` 与 `.tools/` 被本目录的 `.gitignore` 排除。使用 `O=` 独立输出目录，上游源码文件保持原样。

Git 按以下顺序管理：

1. 原始上游提交：`1b357ecb321392158d507b04672ffee57bfa071d`，tag 为 `v6.18.54`。保留原始作者、提交元数据和源码树，没有重新打包成另一个根提交。
2. 学习分支 `codex/aa-reference-6.18`：在上述提交上单独提交本目录的配置、脚本和说明。

因此当前 `HEAD` 可以不同于上游提交；`make check-source` 核验 tag、祖先关系，并要求已提交的上游文件与基线一致，仅允许 `_aa_reference/` 的提交差异。它不检查尚未提交的源码编辑；运行对照实验前请用 `git diff` 确认这些修改。固定提交由 [upstream.commit](upstream.commit) 保存，新补丁版不自动改变基线。

个人仓库为 [s-infinite-box/linux](https://github.com/s-infinite-box/linux)，Fork 自 `gregkh/linux`，默认分支为 `codex/aa-reference-6.18`。本地远程分工如下：

| 远程 | 地址 | 用途 |
| --- | --- | --- |
| `origin` | `https://github.com/s-infinite-box/linux.git` | 保存并推拉我们的学习分支，同时保留纯上游 `linux-6.18.y` |
| `upstream` | `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git` | 直接观察官方 6.18 stable 分支更新 |

学习分支跟踪 `origin/codex/aa-reference-6.18`，默认推送远程为 `origin`。当前仍是浅克隆，包含完整当前源码树及本地实验提交，不包含全部内核开发历史；比较更早的历史时再按需深化。远程抓取范围限定到本实验相关分支，固定 tag 继续保留。

在学习分支上日常同步自己的修改：

```sh
git pull --ff-only
# 修改文件后按需 git add 和 git commit，再推送自己的提交：
git push
```

查看上游新修复与自己的修改：

```sh
git fetch upstream
# 上游相对固定基线新增了什么：
git log --oneline v6.18.54..upstream/linux-6.18.y
# 我们相对固定基线提交了什么、改了哪些文件：
git log --oneline v6.18.54..codex/aa-reference-6.18
git diff --stat v6.18.54 codex/aa-reference-6.18
```

`fetch` 不改变当前工作区或学习基线。若要同步个人 Fork 中的纯上游分支，可在抓取后执行以下普通推送；它不会移动学习分支：

```sh
git push origin refs/remotes/upstream/linux-6.18.y:refs/heads/linux-6.18.y
```

固定基线仍为 `v6.18.54`；升级需显式讨论并同步锁文件、配置与验证记录。其他常用检查：

```sh
git log --oneline --decorate -3
git diff v6.18.54 -- _aa_reference
git status --short
make -C _aa_reference check-source
```

## 2. 构建与运行

需要 GCC、binutils、make、flex、bison、bc、OpenSSL/libelf/zlib 开发文件、Python 3、QEMU、GDB，以及静态链接的 BusyBox。当前实验不启用 BTF，因此不需要 pahole；也不启用 Linux Rust 驱动构建。

本机已将缺少的依赖解包到 `.tools/`。Fedora 上可重复执行：

```sh
# 只从官方 Fedora 仓库下载 RPM 到项目内并解包，不安装宿主系统软件包。
bash _aa_reference/prepare-tools.sh
```

其他主机可自行准备对应工具，并通过 `BUSYBOX=/path/to/static-busybox` 指定静态 BusyBox；不需要使用 Fedora 的可选脚本。

```sh
# 首次构建较久；默认使用 16 个编译任务，可覆盖 JOBS。
make -C _aa_reference build JOBS=16
make -C _aa_reference run
```

产物包括 `build/vmlinux`（GDB 符号与 DWARF 信息）、`build/arch/x86/boot/bzImage`（QEMU 启动镜像）和 `build/initramfs.cpio`（最小用户空间）。`-aa-ref` 是实验配置的 LOCALVERSION 后缀。

进入串口 shell 后可执行：

```sh
uname -a
cat /proc/cpuinfo
dmesg
poweroff -f
```

这些命令运行于客户机，客户机没有挂载宿主磁盘。initramfs 的改动在关机后消失。`poweroff -f` 正常关闭客户机并退出 QEMU；也可以在 QEMU 终端按 Ctrl-C 终止实验。

## 3. 两终端调试

终端一：

```sh
make -C _aa_reference debug
```

终端二：

```sh
make -C _aa_reference gdb
```

GDB 加载 `build/vmlinux`，连接 `127.0.0.1:1235`，设置 `hbreak *start_kernel` 后继续，停在 `init/main.c:start_kernel` 的机器入口。可用 `list`、`bt`、`si`、`next` 和 `continue`。源码仍按正常内核优化级别编译，源码级单步可能跨行；需要精确查看 CPU 指令时使用 `si`。

QEMU 配置固定为 `q35`、TCG、`qemu64`、单核、512 MiB、COM1 串口、无网络。内核关闭 KASLR，并携带 `nokaslr` 启动参数，使符号地址可直接对应。端口可通过两个终端都设置 `GDB_PORT=...` 更改，默认与 aa 的 1234 分开。

该入口直接使用 QEMU 的 `-kernel/-initrd/-append` 加载 Linux bzImage，遵循 Linux x86 启动协议；它不经过 aa 的 GRUB/Multiboot2 入口。因此它验证现代 Linux 的启动与初始化，不等价于验证 aa 的引导代码。

## 4. 自动启动验证

```sh
make -C _aa_reference test
make -C _aa_reference test-debug
```

实验要求 90 秒内到达 initramfs 的 PID 1，打印 `[PASS] linux-reference userspace pid=1`，随后正常关机。宿主同时核对 QEMU 正常退出和 `Power down`，完整串口日志保存在 `build/boot-test.log`。

`test-debug` 还会实际命中 `start_kernel`，核对 PC、CR0.PG 与 CR4.PAE，再解除断点并继续启动。GDB 与串口证据分别保存在 `build/gdb-check.log`、`build/gdb-boot.log`；测试完成后自动清理自己启动的 QEMU。

上游调试说明位于 `Documentation/process/debugging/gdb-kernel-debugging.rst`。当前脚本使用 GDB 基本功能，不依赖 Linux Python 辅助命令的自动加载。
