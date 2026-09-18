"""Run one host and three clients. Pass the Godot executable as the first argument."""
from pathlib import Path
import subprocess
import sys
import tempfile
import time

project = Path(__file__).resolve().parents[1]
godot = sys.argv[1] if len(sys.argv) > 1 else "godot"
command = [godot, "--headless", "--path", str(project), "--script", "res://tests/network_test.gd", "--"]
processes = []
logs = []
failed = False
with tempfile.TemporaryDirectory(prefix="gladiator-network-") as folder:
    try:
        for role in ["host", "client", "client", "client"]:
            log = open(Path(folder) / f"{len(processes)}-{role}.log", "w+")
            logs.append(log)
            processes.append(subprocess.Popen(command + [role], stdout=log, stderr=log))
            if role == "host":
                time.sleep(1.5)
        for process in processes:
            process.wait(timeout=35)
        for index, (process, log) in enumerate(zip(processes, logs)):
            log.seek(0)
            output = log.read()
            print(f"PROCESS {index} (exit {process.returncode})\n{output}")
            failed |= process.returncode != 0 or "SCRIPT ERROR" in output or "ERROR:" in output or "NETWORK RESULT" not in output
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
        for log in logs:
            log.close()
sys.exit(1 if failed else 0)
