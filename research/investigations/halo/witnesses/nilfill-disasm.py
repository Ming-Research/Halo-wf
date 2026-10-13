#!/usr/bin/env python3
"""CI-only x86-64 GNU objdump loop evidence for the nil-fill investigation.

Native nm/objdump retain the evidence; this helper adds bounded CFG path counts,
which those tools do not supply. Keep it while this investigation needs
reproduction; remove it when superseded. It does not identify a source loop.
"""

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import subprocess
import sys


@dataclass(frozen=True)
class Instruction:
    address: int
    mnemonic: str
    operands: str
    line: str

    @property
    def padding(self):
        # objdump emits both nop and prefixed alignment instructions.
        return bool(re.match(r"(?:[a-z0-9]+\s+)*nop[a-z]*\b", self.mnemonic + " " + self.operands))

    @property
    def jump(self):
        return self.mnemonic.startswith("j") or self.mnemonic.startswith("loop")

    @property
    def target(self):
        match = re.match(r"\s*([0-9a-f]+)\s*(?:<|$)", self.operands)
        return int(match[1], 16) if match else None

    @property
    def memory_write(self):
        # AT&T destinations are last. Split only commas outside parentheses.
        operands = re.split(r",(?![^()]*\))", self.operands)
        return self.mnemonic.startswith(("mov", "vmov", "stos")) and (
            self.mnemonic.startswith("stos") or "(" in operands[-1]
        )


def parse(text):
    functions = {}
    current = None
    for line in text.splitlines():
        symbol = re.match(r"^\s*[0-9a-f]+ <(.+)>:$", line)
        if symbol:
            current = symbol[1]
            functions.setdefault(current, [])
            continue
        instruction = re.match(r"^\s*([0-9a-f]+):\s+([a-z][a-zA-Z0-9_.]*)\s*(.*)$", line)
        if instruction and current is not None:
            functions[current].append(Instruction(int(instruction[1], 16), instruction[2], instruction[3], line))
    return functions


def innermost(instructions):
    addresses = {item.address for item in instructions}
    intervals = sorted({(item.target, item.address) for item in instructions
                        if item.jump and item.target in addresses and item.target < item.address})
    # Report every innermost address interval, never guess which is nil-fill.
    return [(header, latch) for header, latch in intervals
            if not any(header <= inner_header and inner_latch <= latch
                       and (header, latch) != (inner_header, inner_latch)
                       for inner_header, inner_latch in intervals)]


def paths(instructions, header, latch):
    """Enumerate acyclic paths to the selected taken back-edge, within its interval.

    Counts include the latch instruction. Branch feasibility is unknown; callees
    are not counted. Return explicit uncertainty rather than an invented count.
    """
    by_address = {item.address: index for index, item in enumerate(instructions)}
    results = []
    problems = set()
    explored = 0

    def visit(address, visited, executed):
        nonlocal explored
        explored += 1
        if explored > 4096 or len(results) >= 128:
            problems.add("path enumeration limit exceeded")
            return
        if address < header or address > latch:
            problems.add("path leaves the address interval; it may re-enter before the latch, so path accounting is incomplete")
            return  # Out-of-interval path; omitted pending manual accounting.
        if address not in by_address:
            problems.add("jump target is not a parsed instruction")
            return
        if address in visited:
            problems.add("another cycle lies on a path to the back-edge")
            return
        item = instructions[by_address[address]]
        executed = executed + [item]
        if item.mnemonic.startswith("call"):
            problems.add("callee instructions are excluded from these caller-path counts")
        if address == latch:
            if item.target == header:
                results.append(executed)
            else:
                problems.add("selected latch does not jump to its header")
            return
        if item.mnemonic.startswith(("ret", "ud2", "hlt")):
            return
        next_index = by_address[address] + 1
        next_address = instructions[next_index].address if next_index < len(instructions) else latch + 1
        successors = []
        if item.jump:
            if item.target is None:
                problems.add("indirect or unparsed branch")
                return
            successors.append(item.target)
            if item.mnemonic not in ("jmp", "jmpq"):
                successors.append(next_address)
        else:
            successors.append(next_address)
        for successor in dict.fromkeys(successors):
            visit(successor, visited | {address}, executed)

    try:
        visit(header, set(), [])
    except RecursionError:
        problems.add("path depth exceeds Python recursion limit")
    return results, sorted(problems)


def describe(symbol, instructions):
    loops = innermost(instructions)
    if not loops:
        raise ValueError(f"no innermost backward-edge candidates in {symbol}; inspect whole-binary.txt for inlining, vectorization or memset")
    output = []
    for header, latch in loops:
        body = [item for item in instructions if header <= item.address <= latch]
        count = sum(not item.padding for item in body)
        output.append(f"\nSymbol {symbol}: candidate header=0x{header:x}, latch=0x{latch:x}")
        output.extend(item.line for item in body)
        output.append(f"Interval static instruction count, excluding nop padding: {count}")
        alternatives, problems = paths(instructions, header, latch)
        if not alternatives:
            output.append("Path-to-backedge instruction count: UNKNOWN (no parsed completed path)")
        for number, path in enumerate(alternatives, 1):
            stores = [f"0x{item.address:x}" for item in path if item.memory_write]
            output.append(f"Path {number}: {len(path)} instructions including executed padding; "
                          f"{sum(not item.padding for item in path)} excluding padding; "
                          f"memory-write instructions at {', '.join(stores) or 'none'}")
            output.append("  instruction addresses: " + " ".join(f"0x{item.address:x}" for item in path))
        if problems:
            output.append("Path accounting uncertainty: " + "; ".join(problems))
        if any(re.search(r"%(?:[xyz]mm|k)\d+", item.operands) for item in body):
            output.append("Vector/mask registers appear: inspect whether an iteration covers multiple slots.")
        output.append("Store addresses may include spills; identify the nil store by reviewing the whole function. "
                      "Vectorization, unrolling and calls/memset require manual interpretation; a latch is not necessarily one slot.")
    return "\n".join(output) + "\n"


def run_native(command, output, stem):
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    (output / f"{stem}.txt").write_text(result.stdout)
    (output / f"{stem}.stderr.txt").write_text(result.stderr)
    (output / f"{stem}.exit-code").write_text(f"{result.returncode}\n")
    (output / f"{stem}.command.txt").write_text(repr(command) + "\n")
    if result.returncode:
        raise ValueError(f"{command[0]} failed ({result.returncode}): {result.stderr.strip()}")
    return result.stdout


def extract(binary, kind, output):
    output.mkdir(parents=True, exist_ok=True)
    symbols_text = run_native(["nm", "--defined-only", str(binary)], output, "nm")
    # Save nm first, then grep: neither tool's exit code is hidden by a pipe.
    pattern = "enter_lua" if kind == "halo" else "nilfill_"
    result = subprocess.run(["grep", pattern, str(output / "nm.txt")], text=True, capture_output=True, check=False)
    (output / "symbol-matches.txt").write_text(result.stdout)
    (output / "symbol-grep.exit-code").write_text(f"{result.returncode}\n")
    if result.returncode not in (0, 1):
        raise ValueError(f"symbol grep failed ({result.returncode}): {result.stderr.strip()}")
    print(f"nm matches for {pattern}:\n{result.stdout}", end="")
    run_native(["objdump", "-d", "--no-show-raw-insn", str(binary)], output, "whole-binary")
    text_symbols = []
    for line in symbols_text.splitlines():
        match = re.match(r"^\s*[0-9a-f]+\s+[tT]\s+(.+)$", line)
        if match:
            text_symbols.append(match[1])
    selected = [symbol for symbol in text_symbols if pattern in symbol]
    if not selected and kind != "halo":
        selected = [symbol for symbol in text_symbols if "main" in symbol]
        print("Witness function may have inlined: inspecting all text symbols containing main.")
    if not selected:
        raise ValueError(f"no matching text symbol for {kind}; whole-binary.txt retains any inlined implementation")
    (output / "selected-symbols.txt").write_text("\n".join(selected) + "\n")
    reports = []
    found = 0
    for index, symbol in enumerate(selected, 1):
        function = run_native(["objdump", "-d", "--no-show-raw-insn", f"--disassemble={symbol}", str(binary)], output, f"function-{index}")
        print(function)
        instructions = parse(function).get(symbol, [])
        if not instructions:
            raise ValueError(f"objdump did not return instructions for {symbol}")
        if innermost(instructions):
            report = describe(symbol, instructions)
            found += 1
        else:
            report = f"No backward-edge candidate in {symbol}; retained for inlining/memset review.\n"
        reports.append(report)
        (output / f"loops-{index}.txt").write_text(report)
        print(report)
    (output / "loop-counts.txt").write_text("\n".join(reports))
    if not found:
        raise ValueError("no loops found in selected functions; inspect whole-binary.txt for inlining, vectorization, unrolling or memset")
    print("Identification remains manual: these are all innermost backward-edge candidates, not confirmed nil-fill loops. "
          "Static interval counts include mutually exclusive blocks; caller path counts do not establish Callgrind Ir per slot.")


def self_check():
    sample = """0000000000000100 <nilfill_checked>:
 100: cmp %rsi,%rax
 104: jae 110 <nilfill_checked+0x10>
 106: movq $0x0,(%rdx)
 10a: add $0x10,%rdx
 10e: jmp 114 <nilfill_checked+0x14>
 110: nop
 114: add $0x1,%rax
 118: cmp %rcx,%rax
 11c: jb 100 <nilfill_checked>
 120: ret
"""
    items = parse(sample)["nilfill_checked"]
    assert innermost(items) == [(0x100, 0x11c)], "back-edge detection failed"
    alternatives, problems = paths(items, 0x100, 0x11c)
    assert not problems, problems
    observed = sorted((len(path), sum(not item.padding for item in path), sum(item.memory_write for item in path)) for path in alternatives)
    assert observed == [(6, 5, 0), (8, 8, 1)], observed
    assert sum(not item.padding for item in items if item.address <= 0x11c) == 8
    missing = parse(sample.replace("jb 100 <nilfill_checked>", "jb 120 <nilfill_checked+0x20>"))["nilfill_checked"]
    try:
        describe("nilfill_checked", missing)
    except ValueError:
        pass
    else:
        raise AssertionError("missing-loop mutant did not fail")
    escaped = parse(sample.replace("jmp 114 <nilfill_checked+0x14>", "jmp 124 <nilfill_checked+0x24>") + " 124: movq $0x0,(%rdx)\n 128: jmp 114 <nilfill_checked+0x14>\n")["nilfill_checked"]
    escape_paths, escape_problems = paths(escaped, 0x100, 0x11c)
    assert escape_paths, "the in-interval skip path should still be reported"
    assert any("may re-enter" in problem for problem in escape_problems), escape_problems
    print("PASS: backward edge, static padding count, distinct store/skip path counts, missing-loop failure, and escaped-path uncertainty.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-check", action="store_true")
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--kind", choices=("halo", "nilfill-checked", "nilfill-proved"))
    parser.add_argument("--out", type=Path)
    arguments = parser.parse_args()
    if arguments.self_check:
        self_check()
    elif arguments.binary is None or arguments.kind is None or arguments.out is None:
        parser.error("extraction requires --binary, --kind and --out")
    else:
        extract(arguments.binary, arguments.kind, arguments.out)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
