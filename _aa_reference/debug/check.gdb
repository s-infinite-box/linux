# 批处理验证复用交互脚本，要求实际命中入口并确认分页与 PAE 已开启。
source debug/start.gdb
if $pc != (unsigned long)&start_kernel
    echo [FAIL] PC is not start_kernel\n
    quit 1
end
if ($cr0 & 0x80000000) == 0 || ($cr4 & 0x20) == 0
    echo [FAIL] paging or PAE is disabled\n
    quit 1
end
x/s linux_banner
echo [PASS] GDB stopped at start_kernel with paging and PAE enabled\n
# 释放断点并恢复客户机，让带 aa_ref_test=1 的 PID 1 自行关机。
delete breakpoints
detach
quit
