#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
import ast
from pathlib import Path
import py_compile

source = Path("/tmp/run-bcachefs-build-benchmark.py")
py_compile.compile(str(source), doraise=True)
tree = ast.parse(source.read_text())
definition = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "temperature_violation")
namespace = {}
exec(compile(ast.Module(body=[definition], type_ignores=[]), str(source), "exec"), namespace)
violation = namespace["temperature_violation"]
for cpu, alarm, ssd, allow, expected in [
    (99, False, 30, False, False),
    (100, False, 30, False, True),
    (100, False, 30, True, False),
    (101, False, 30, True, True),
    (90, True, 30, True, True),
    (90, False, 80, True, True),
]:
    sample = {"cpu_c": cpu, "cpu_critical_alarm": alarm, "ssd_composite_c": ssd}
    assert bool(violation(sample, allow)) == expected, sample
for cpu, expected in [(94.875, False), (95, False), (95.125, True)]:
    assert bool(violation({"cpu_c": cpu, "cpu_critical_alarm": False, "ssd_composite_c": 50}, True, 95)) == expected
print("Intel/AMD temperature boundaries and CPU/SSD alarm checks passed")
