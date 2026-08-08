#!/usr/bin/env python3
"""Run one WGX validation task with a process-group timeout."""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import NoReturn


def _usage() -> NoReturn:
    raise SystemExit(
        "usage: validate_runner.py TIMEOUT_SECONDS REPOSITORY_ROOT WGX_EXECUTABLE TASK"
    )


def _group_exists(process_group: int) -> bool:
    try:
        os.killpg(process_group, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _signal_group(process_group: int, signum: signal.Signals) -> None:
    try:
        os.killpg(process_group, signum)
    except ProcessLookupError:
        pass


def _exit_code(returncode: int) -> int:
    return 128 + (-returncode) if returncode < 0 else returncode


def main() -> int:
    if len(sys.argv) != 5:
        _usage()

    try:
        timeout_seconds = int(sys.argv[1])
    except ValueError:
        _usage()
    if timeout_seconds <= 0:
        _usage()

    repository_root = Path(sys.argv[2])
    executable = Path(sys.argv[3])
    task = sys.argv[4]
    if not repository_root.is_dir() or not executable.is_file() or not task:
        _usage()

    started = time.monotonic_ns()
    process = subprocess.Popen(
        [str(executable), "task", task],
        cwd=repository_root,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        close_fds=True,
    )
    process_group = process.pid
    timed_out = False

    try:
        returncode = process.wait(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        timed_out = True
        _signal_group(process_group, signal.SIGTERM)

        grace_deadline = time.monotonic() + 1.0
        while time.monotonic() < grace_deadline:
            process.poll()
            if not _group_exists(process_group):
                break
            time.sleep(0.05)
        if _group_exists(process_group):
            _signal_group(process_group, signal.SIGKILL)

        if process.returncode is None:
            try:
                returncode = process.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                _signal_group(process_group, signal.SIGKILL)
                returncode = process.wait()
        else:
            returncode = process.returncode

    duration_ms = max(0, (time.monotonic_ns() - started) // 1_000_000)
    if timed_out:
        status, exit_code = "timeout", 124
    else:
        exit_code = _exit_code(returncode)
        status = "passed" if exit_code == 0 else "failed"

    print(f"{status} {exit_code} {duration_ms}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
