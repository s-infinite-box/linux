#!/usr/bin/env python3
"""启动本实验的 QEMU，验证 GDB 断点，再验证客户机 PID 1 正常关机。"""

import socket
import subprocess
import sys
from pathlib import Path


def main():
    port = int(sys.argv[1])
    # 避免误连已在该端口运行的其他调试实例。
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", port))

    build = Path("build")
    serial_log = build / "gdb-boot.log"
    gdb_log = build / "gdb-check.log"
    qemu_args = sys.argv[2:] + ["-S", "-gdb", f"tcp:127.0.0.1:{port}"]
    with serial_log.open("w") as serial:
        qemu = subprocess.Popen(qemu_args, stdout=serial, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL)
        try:
            with gdb_log.open("w") as output:
                subprocess.run(
                    ["gdb", "-nx", "-q", "-batch",
                     "-ex", "set auto-load python-scripts off",
                     "-ex", "file build/vmlinux",
                     "-ex", f"target remote 127.0.0.1:{port}",
                     "-x", "debug/check.gdb"],
                    stdout=output, stderr=subprocess.STDOUT, check=True, timeout=60,
                )
            if qemu.wait(timeout=90) != 0:
                raise RuntimeError(f"QEMU 启动失败，见 {serial_log}")
        finally:
            # 只清理本脚本创建的进程，不影响 aa 或用户的其他 QEMU。
            if qemu.poll() is None:
                qemu.terminate()
                try:
                    qemu.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    qemu.kill()
                    qemu.wait()

    checks = (
        (gdb_log, "[PASS] GDB stopped at start_kernel with paging and PAE enabled"),
        (serial_log, "[PASS] linux-reference userspace pid=1"),
        (serial_log, "Power down"),
    )
    for path, marker in checks:
        if marker not in path.read_text():
            raise RuntimeError(f"{path} 缺少成功标记：{marker}")
        print(marker)


if __name__ == "__main__":
    main()
