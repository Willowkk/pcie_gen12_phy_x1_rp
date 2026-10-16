#!/usr/bin/env python3
"""Check the Verilog RTL, SV verification sources, and a Git SV baseline.

Requires pyslang. This audits the source manifest and relocated SV packages,
lexically rejects SV keywords/constructs and time literals in RTL, permits only
$clog2/$display/$time/$stop/$finish, and checks strict Verilog-2005 parsing,
semantic elaboration, interfaces and known-valued parameters. Comments, strings,
escaped identifiers and `timescale directive units are excluded from lexical
checks. This does not perform simulation or formal equivalence.
Optional Icarus compilation uses strict IEEE 1364-2005 and ignores unresolved
vendor modules, whose names are checked separately by pyslang.
"""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

try:
    import pyslang
except ImportError:
    print(json.dumps({"ok": False, "error": "pyslang is required"}))
    sys.exit(1)


VENDOR_MODULES = {"IBUFDS_GTE4", "BUFG_GT", "GTYE4_CHANNEL"}
PACKAGE_NAMES = ("pcie_gen12_phy_pkg.sv", "pcie_gen12_phy_timing_pkg.sv")
ALLOWED_SYSTEM_NAMES = {"$clog2", "$display", "$time", "$stop", "$finish"}
SV_KEYWORDS = set("""
accept_on alias always_comb always_ff always_latch assert assume before bind
bins binsof bit break byte chandle checker class clocking const constraint
context continue cover covergroup coverpoint cross dist do endchecker endclass
endclocking endgroup endinterface endpackage endprogram endproperty endsequence
enum eventually expect export extends extern final first_match foreach forkjoin
global iff ignore_bins illegal_bins implements implies import inside int
interconnect interface intersect join_any join_none let local logic longint
matches modport nettype new nexttime null package packed priority program
property protected pure rand randc randcase randsequence ref reject_on restrict
return s_always s_eventually s_nexttime s_until s_until_with sequence shortint
shortreal soft solve static string strong struct super sync_accept_on
sync_reject_on tagged this throughout timeprecision timeunit type typedef union
unique unique0 unsigned until until_with untyped var virtual void wait_order
weak wildcard with within
""".split())
NON_CODE = re.compile(
    r'//[^\r\n]*|/\*[\s\S]*?\*/|"(?:\\[\s\S]|[^"\\])*"|\\[^\s]+'
)
IDENTIFIER = re.compile(r"(?<![A-Za-z0-9_$])[A-Za-z_][A-Za-z0-9_$]*")
SYSTEM_NAME = re.compile(r"(?<![A-Za-z0-9_$])\$[A-Za-z_][A-Za-z0-9_$]*")
TIME_LITERAL = re.compile(
    r"(?<![A-Za-z0-9_$])[0-9][0-9_]*(?:\.[0-9_]+)?"
    r"(?:[eE][+-]?[0-9_]+)?(?:ns|ps|us|ms|fs|s)\b"
)
SV_SYNTAX = re.compile(
    r"::|\.\*|'\s*\{|(?<![A-Za-z0-9_$])'[01xXzZ](?![A-Za-z0-9_$])"
    r"|(?<![A-Za-z0-9_$])[0-9][0-9_]*\s*'\s*\("
    r"|\+\+|--|(?:<<<|>>>|<<|>>|[+*/%&^|\-])=|->>|##|\{\s*(?:<<|>>)"
)


def lexical_verilog_violations(source: str) -> tuple[list[dict], set[str]]:
    """Supplement parser language mode, which permits some SV system functions."""
    code = NON_CODE.sub(
        lambda match: re.sub(r"[^\r\n]", " ", match.group()), source
    )
    code = re.sub(r"(?m)^[ \t]*`timescale[^\r\n]*", "", code)
    violations = []
    system_names = {match.group() for match in SYSTEM_NAME.finditer(code)}
    for kind, pattern in (
        ("SystemVerilog keyword", IDENTIFIER),
        ("unsupported system task/function", SYSTEM_NAME),
        ("SystemVerilog time literal", TIME_LITERAL),
        ("SystemVerilog syntax", SV_SYNTAX),
    ):
        for match in pattern.finditer(code):
            token = match.group()
            if kind == "SystemVerilog keyword" and token not in SV_KEYWORDS:
                continue
            if kind == "unsupported system task/function" and token in ALLOWED_SYSTEM_NAMES:
                continue
            violations.append({"kind": kind, "token": token,
                               "line": code.count("\n", 0, match.start()) + 1})
    return violations, system_names


def check_rtl_lexically(root: Path, sources: list[Path]) -> dict:
    checked = 0
    used_system_names = set()
    for source in sources:
        if source.relative_to(root).parts[0] != "rtl":
            continue
        checked += 1
        violations, system_names = lexical_verilog_violations(
            source.read_text(encoding="utf-8-sig")
        )
        used_system_names.update(system_names)
        if violations:
            raise RuntimeError(f"Non-Verilog RTL in {source.relative_to(root)}: "
                               + json.dumps(violations))
    return {"passed": True, "files_checked": checked,
            "allowed_system_tasks_functions": sorted(ALLOWED_SYSTEM_NAMES),
            "used_system_tasks_functions": sorted(used_system_names),
            "sv_keyword_syntax_time_literal_checks": True}


def git(root: Path, *args: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, check=False
    )
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace").strip())
    return result.stdout


def read_manifest(root: Path, audit: bool = False) -> list[Path]:
    manifest = root / "scripts/filelist.f"
    names = [
        line.strip()
        for line in manifest.read_text(encoding="utf-8-sig").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    duplicates = [name for name, count in Counter(names).items() if count > 1]
    if duplicates:
        raise RuntimeError(f"Duplicate manifest entries: {duplicates}")
    sources = [(root / name).resolve() for name in names]
    for source in sources:
        if not source.is_relative_to(root.resolve()) or not source.is_file():
            raise RuntimeError(f"Missing or out-of-tree source: {source}")
    if len(set(sources)) != len(sources):
        raise RuntimeError("Manifest aliases the same source more than once")
    if audit:
        actual = {
            path.resolve()
            for folder in (root / "rtl", root / "tb")
            for path in folder.rglob("*")
            if path.is_file() and path.suffix.lower() in (".v", ".sv")
        }
        if actual != set(sources):
            missing = sorted(str(p.relative_to(root)) for p in actual - set(sources))
            extra = sorted(str(p.relative_to(root)) for p in set(sources) - actual)
            raise RuntimeError(f"Manifest source mismatch: omitted={missing}, extra={extra}")
        rtl_sources = [p for p in sources if p.relative_to(root).parts[0] == "rtl"]
        if any(p.suffix.lower() != ".v" for p in rtl_sources):
            raise RuntimeError("Every RTL source must use the .v extension")
        for name in PACKAGE_NAMES:
            expected = root / "tb/tb_common" / name
            matches = list(root.rglob(name))
            if matches != [expected] or expected.resolve() not in sources:
                raise RuntimeError(f"SV compatibility package must exist only at {expected}")
    return sources


def type_signature(data_type) -> dict:
    return {
        "width": data_type.bitWidth,
        "signed": data_type.isSigned,
        "four_state": data_type.isFourState,
    }


def inspect_sources(root: Path, defines: list[str], rtl_only: bool = False,
                    strict_verilog: bool = False) -> tuple[dict, dict]:
    sources = read_manifest(root)
    if rtl_only:
        sources = [p for p in sources if p.relative_to(root).parts[0] == "rtl"]
    options = ["slang", *("-D" + define for define in defines)]
    if strict_verilog:
        options.extend(["--std", "1364-2005"])
    driver = pyslang.driver.Driver()
    driver.addStandardArgs()
    # Driver consumes its first token as the executable name.
    command = " ".join(options + ['"' + str(path) + '"' for path in sources])
    if not (driver.parseCommandLine(command) and driver.processOptions()
            and driver.parseAllSources()):
        raise RuntimeError(f"pyslang could not parse sources for {defines}")
    compilation = driver.createCompilation()
    elaborated = compilation.getRoot()
    diagnostics = compilation.getAllDiagnostics()
    errors = []
    for diagnostic in diagnostics:
        if diagnostic.isError():
            errors.append({
                "code": str(diagnostic.code),
                "args": [str(arg) for arg in diagnostic.args],
                "file": str(driver.sourceManager.getFileName(diagnostic.location)),
                "line": driver.sourceManager.getLineNumber(diagnostic.location),
            })
    allowed = []
    unexpected = []
    for error in errors:
        if ("GT_BEHAV_MODEL" not in defines
                and error["code"] == "DiagCode(UnknownModule)"
                and error["args"] and error["args"][0] in VENDOR_MODULES):
            allowed.append(error)
        else:
            unexpected.append(error)
    if "GT_BEHAV_MODEL" not in defines:
        found = {error["args"][0] for error in allowed}
        if found != VENDOR_MODULES or len(allowed) != len(VENDOR_MODULES):
            raise RuntimeError(f"Native GT unresolved modules changed: {allowed}")
    instances = {}

    def visit(node):
        if not isinstance(node, pyslang.ast.InstanceSymbol):
            return
        filename = str(driver.sourceManager.getFileName(node.definition.location))
        filename = filename.replace("\\", "/")
        if "/rtl/" not in filename and not filename.startswith("rtl/"):
            return
        ports = [{
            "name": port.name,
            "direction": str(port.direction),
            **type_signature(port.type),
        } for port in node.body.portList]
        parameters = [{
            "name": parameter.name,
            "value": str(parameter.value),
            **type_signature(parameter.type),
        } for parameter in node.body.parameters if not parameter.isLocalParam]
        instances[node.hierarchicalPath] = {
            "module": node.definition.name, "ports": ports, "parameters": parameters,
        }

    elaborated.visit(visit)
    summary = {
        "source_count": len(sources),
        "parse_diagnostics": len(compilation.getParseDiagnostics()),
        "unexpected_errors": unexpected,
        "allowed_vendor_modules": sorted(error["args"][0] for error in allowed),
        "non_error_diagnostics": len(diagnostics) - len(errors),
        "rtl_instance_count": len(instances),
        "rtl_module_count": len({item["module"] for item in instances.values()}),
    }
    if summary["parse_diagnostics"] or unexpected:
        raise RuntimeError("Parse/elaboration failure: " + json.dumps(summary))
    return summary, instances


def compare_interfaces(original: dict, converted: dict) -> dict:
    differences = []
    state_domain_changes = 0
    parameter_count = 0
    for name in sorted(set(original) | set(converted)):
        if name not in original or name not in converted:
            differences.append({"instance": name, "kind": "presence"})
            continue
        before, after = original[name], converted[name]
        for key in ("module", "ports"):
            if before[key] != after[key]:
                differences.append({"instance": name, "kind": key})
        old_params, new_params = before["parameters"], after["parameters"]
        # Verilog vectors are four-state; compare known values, widths and signs.
        old_known = [{k: v for k, v in p.items() if k != "four_state"} for p in old_params]
        new_known = [{k: v for k, v in p.items() if k != "four_state"} for p in new_params]
        if old_known != new_known:
            differences.append({"instance": name, "kind": "known_parameters",
                                "original": old_known, "converted": new_known})
        parameter_count += len(old_params)
        state_domain_changes += sum(
            left["four_state"] != right["four_state"]
            for left, right in zip(old_params, new_params)
        )
    if differences:
        raise RuntimeError("Baseline interface differences: " + json.dumps(differences))
    top_ports = next(
        item["ports"] for item in converted.values()
        if item["module"] == "pcie_gen12_phy_x1_rp"
    )
    return {
        "interface_differences": 0,
        "known_parameter_differences": 0,
        "compared_parameter_occurrences": parameter_count,
        "parameter_state_domain_changes": state_domain_changes,
        "top_ports": len(top_ports),
        "top_inputs": sum(p["direction"] == "ArgumentDirection.In" for p in top_ports),
        "top_outputs": sum(p["direction"] == "ArgumentDirection.Out" for p in top_ports),
    }


def run_iverilog(executable: str, sources: list[Path], defines: list[str]) -> dict:
    resolved = shutil.which(executable) or executable
    result = subprocess.run(
        [resolved, "-g2005", "-i", "-tnull",
         *("-D" + define for define in defines), *(str(source) for source in sources)],
        capture_output=True, text=True, errors="replace", check=False,
    )
    if result.returncode:
        raise RuntimeError("Icarus compile failed: " + result.stdout + result.stderr)
    return {"exit_code": result.returncode,
            "diagnostic_lines": len((result.stdout + result.stderr).splitlines())}


def main() -> dict:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", default="156401f",
                        help="Git revision containing the original SV RTL")
    parser.add_argument("--iverilog", help="Optional Icarus executable, supporting -i")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    sources = read_manifest(root, audit=True)
    lexical_gate = check_rtl_lexically(root, sources)
    baseline_commit = git(root, "rev-parse", args.baseline + "^{commit}").decode().strip()
    report = {
        "ok": True, "baseline": baseline_commit,
        "pyslang_version": getattr(pyslang, "__version__", "unknown"),
        "manifest_sources": len(sources),
        "rtl_files": sum(path.relative_to(root).parts[0] == "rtl" for path in sources),
        "compatibility_packages_byte_identical": True,
        "rtl_lexical_gate": lexical_gate,
        "scope": "Static compilation and known-parameter interface checks; no formal equivalence",
        "parameter_note": "SV two-state parameter types become four-state Verilog vectors; known values are compared",
        "configurations": {},
    }
    with tempfile.TemporaryDirectory(prefix="pcie_sv_baseline_") as temporary:
        original_root = Path(temporary).resolve()
        names = git(root, "ls-tree", "-r", "--name-only", baseline_commit, "--",
                    "rtl", "tb", "scripts/filelist.f").decode().splitlines()
        for name in names:
            path = original_root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(git(root, "show", baseline_commit + ":" + name))
        for name in PACKAGE_NAMES:
            original = original_root / "rtl/pkg" / name
            converted = root / "tb/tb_common" / name
            if original.read_bytes() != converted.read_bytes():
                raise RuntimeError(f"Compatibility package changed: {name}")
        rtl_sources = [p for p in sources if p.relative_to(root).parts[0] == "rtl"]
        for behavioral in (False, True):
            for synthesis in (False, True):
                defines = (["GT_BEHAV_MODEL"] if behavioral else [])
                if synthesis:
                    defines.append("SYNTHESIS")
                key = f"GT_BEHAV_MODEL={int(behavioral)},SYNTHESIS={int(synthesis)}"
                strict, _ = inspect_sources(root, defines, rtl_only=True, strict_verilog=True)
                mixed, converted = inspect_sources(root, defines)
                baseline, original = inspect_sources(original_root, defines)
                configuration = {
                    "strict_verilog_rtl": strict,
                    "mixed_sv_testbenches": mixed,
                    "baseline": baseline,
                    "comparison": compare_interfaces(original, converted),
                }
                if args.iverilog:
                    configuration["iverilog_g2005"] = run_iverilog(
                        args.iverilog, rtl_sources, defines
                    )
                report["configurations"][key] = configuration
    return report


if __name__ == "__main__":
    try:
        result = main()
    except (OSError, RuntimeError, ValueError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=True))
        sys.exit(1)
    print(json.dumps(result, indent=2, ensure_ascii=True))
