# 在内核装载前使用硬件断点；nokaslr 与固定构建配置保证符号地址可对应。
set pagination off
set disassembly-flavor intel
set breakpoint pending off
hbreak *start_kernel
continue
echo \n已停在现代 Linux 的 start_kernel 机器入口。\n
info registers rip rsp cr0 cr3 cr4
list start_kernel
echo \n可用 list、bt、si、next 观察；continue 继续启动 BusyBox。\n
