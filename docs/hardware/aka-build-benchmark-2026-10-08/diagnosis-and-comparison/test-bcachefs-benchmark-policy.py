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
selection = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "cpu_control_temperature")
exec(compile(ast.Module(body=[selection], type_ignores=[]), str(source), "exec"), namespace)
control = namespace["cpu_control_temperature"]
# Recorded Aka cutoff regression: CCD is not the control channel.
channels = {"k10temp:Tccd1": 95.25, "k10temp:Tctl": 88.625}
assert control(channels) == 88.625
assert not violation({"cpu_c": control(channels), "cpu_critical_alarm": False, "ssd_composite_c": 49.85}, True, 95)
assert control({"k10temp:Tdie": 80, "k10temp:Tctl": 90}) == 80
assert control({"coretemp:Core 0": 80, "coretemp:Package id 0": 90}) == 90
transient = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "aka_target_violation")
exec(compile(ast.Module(body=[transient], type_ignores=[]), str(source), "exec"), namespace)
check_target = namespace["aka_target_violation"]
assert check_target(95, 0, None) == (False, None)
assert check_target(95.125, 0, None) == (False, 0)
assert check_target(95.125, 2, 0) == (False, 0)
assert check_target(95.125, 2.01, 0) == (True, 0)
assert check_target(96.125, 0, None)[0]
assert check_target(94.875, 2, 0) == (False, None)
print("Recorded AMD channel-selection regression, transient duration, and hard boundaries passed")
