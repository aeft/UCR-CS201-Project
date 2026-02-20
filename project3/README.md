# CS201 Project 3: Liveness Analysis

This project implements a Liveness Analysis pass for LLVM.

## Task Description

Implement liveness analysis to compute data flow information for each basic block:

**Goal:** For each basic block, compute UEVAR, VARKILL, and LIVEOUT sets

**Definitions:**
- **UEVAR** (Upward-Exposed Variables): Variables used in a block before being defined
- **VARKILL** (Killed Variables): Variables defined/killed in a block
- **LIVEOUT** (Live-Out Variables): Variables that are live at the exit of a block

**Requirements:**
- Compute UEVAR and VARKILL for each basic block in one pass
- Compute LIVEOUT using iterative fixed-point computation:
  - `LIVEOUT(n) = Union over all successors s of n: (UEVAR(s) ∪ (LIVEOUT(s) - VARKILL(s)))`
- Handle the following instruction types:
  - `Store`, `Load`, `Add`, `Sub`, `Mul`, `SDiv`, `UDiv`, `ICmp`, `Br`
  - For bonus, you also need to handle `Ret` instructions
- Only track variables allocated via `alloca` in the entry block
- Print results alphabetically sorted by variable name

**Tips:**
- Use the `entry` block's `Alloca` instructions to identify the set of trackable variables
- For `Load`: source operand is UEVAR candidate, destination (`&inst`) is VARKILL candidate
- For `Store`: source operand (`getOperand(0)`) is UEVAR candidate, destination (`getOperand(1)`) is VARKILL candidate
- For `ICmp`: both operands are UEVAR candidates
- For `Br` (conditional): the condition operand (`getOperand(0)`) is a UEVAR candidate
- For arithmetic (`Add`, `Sub`, `Mul`, `SDiv`, `UDiv`): both operands are UEVAR candidates, result (`&inst`) is VARKILL candidate
- A variable is only added to UEVAR if it is in the variable set and NOT already in the block's VARKILL
- LIVEOUT requires iterating until no changes occur (fixed-point)

**Success Criterion:**
- Your implementation should pass all tests: `./test.sh`

## API Hints

**Useful LLVM APIs:**
- `for (BasicBlock &bb : F)` - Iterate over basic blocks in function
- `for (Instruction &inst : bb)` - Iterate over instructions in basic block
- `inst.getOpcode()` - Get instruction opcode (returns `int`)
  - Compare with instruction constants (e.g., `Instruction::Add`, `Instruction::Store`, etc.)
- `inst.getOperand(i)` - Get the i-th operand (returns `Value*`)
- `bb.getName()` - Get basic block name (returns `StringRef`)
- `successors(&bb)` - Get successor basic blocks (for CFG traversal)
- `inst.getNumOperands()` - Get number of operands (useful for distinguishing conditional vs unconditional branch)

**Key concept:** In LLVM, an Instruction is a Value. `&inst` denotes the SSA value defined by the instruction. For liveness analysis, you track which `Value*` pointers are used (UEVAR) and defined (VARKILL) in each block.

**Useful data structures:**
- `std::set` and `std::map` are useful for tracking sets of variables

**Output:**
- Use `errs()` to print output
- For each basic block, print:
  ```
  ----- <block_name> -----
  UEVAR: <sorted variable names>
  VARKILL: <sorted variable names>
  LIVEOUT: <sorted variable names>
  ```
- Variable names should be sorted alphabetically, each followed by a space

**Example:**
- Input: `./test/basic1.c`
- Expected output: `./test/expected/basic1.txt`

## Bonus: Dead Code Elimination

This is an **optional** bonus task. It does not affect your base grade.

### Overview

After computing liveness analysis, implement Dead Code Elimination (DCE) using use-def chains and topological sort. The idea: if a `store` instruction writes to a variable that is NOT in the block's LIVEOUT set, that store is **dead**. Furthermore, the instructions that produced the stored value may also be dead if they have no other live uses.

You can use any algorithm you want. For example, as an alternative to topological sorting, you can also use an iterative algorithm for this task. But you cannot hack the test (e.g., just return a fixed result).

### Algorithm

1. **Identify dead stores**: After liveness analysis, scan each block for `store` instructions where the destination variable is NOT in LIVEOUT of that block. These are dead stores.

2. **Initialize use counts**: For each instruction that produces an SSA value (load, arithmetic, icmp), record its use count via `getNumUses()`. Note that `store` and `br` do not produce SSA values.

3. **Propagate deadness**: Starting from the dead stores, propagate deadness upstream through operands. An instruction is dead if all of its uses are dead.

4. **Collect and print**: Gather all dead instructions and print them in their original IR appearance order.

### API Hints

- `inst.getNumUses()` — returns the number of users of this instruction's SSA result. Note: `store` and `br` produce no SSA value, so their `getNumUses()` is always 0
- `inst.getNumOperands()` — returns the number of operands
- `inst.getOperand(i)` — get the i-th operand (returns `Value*`)
- `dyn_cast<Instruction>(value)` — cast a `Value*` to `Instruction*` (returns `nullptr` if not an instruction, e.g. constants or alloca pointers)
- `inst.print(errs())` — print the instruction in LLVM IR text format

### Output Format

After the liveness analysis output, print a dead code section:

```
----- Dead Code -----
  <dead instruction 1>
  <dead instruction 2>
  ...
```

Each dead instruction is printed using `inst.print(errs())` which produces the LLVM IR text representation. Instructions should appear in their original IR order (the order they appear in the function).

Please see `./test/expected/bonus1.txt` for an example.

### Bonus Test Cases

Bonus tests use `int test()` functions (with `return`) to test that your liveness analysis correctly handles return values, and that your DCE correctly identifies dead computation chains.

Bonus test results are shown in yellow and do not cause the test script to exit with an error.

## Quick Start

### 1. Install LLVM 21+

**macOS (Homebrew):**
```bash
brew install llvm
```

**Ubuntu/Debian:**
```bash
sudo apt-get install llvm-21-dev clang-21
```

### 2. Implement Your Algorithm

Edit your implementation in:
```
LivenessAnalysis.cpp
```

You only need to edit this file for the project.

### 3. Build and Test

Run all tests:
```bash
./test.sh
```

Run a specific test file (without validation; place your custom test file in `./test`):
```bash
./test.sh -f test_custom.c
```

The script will automatically:
- Detect your LLVM installation
- Build the LLVM pass plugin
- Compile all test cases
- Run your pass on each test
- Compare outputs with expected results

## Manual LLVM Configuration (Optional)

If automatic detection fails, you can manually specify the LLVM installation directory:

```bash
export LLVM_DIR=/path/to/llvm
./test.sh
```

**Common LLVM paths:**
- macOS (Homebrew): `/opt/homebrew/opt/llvm` or `/opt/homebrew/opt/llvm@21`
- Ubuntu/Debian: `/usr/lib/llvm-21` or `/lib/llvm-21`

## Project Structure

```
project3/
├── LivenessAnalysis.cpp               # Your implementation (edit this!)
├── CMakeLists.txt                     # CMake build configuration
├── test.sh                            # Build and test script
├── README.md                          # This file
├── test/
│   ├── basic1.c - basic4.c            # Test cases (C source)
│   ├── bonus1.c, bonus2.c             # Bonus test cases (optional)
│   ├── expected/                      # Expected output for each test
│   └── output/                        # Test output (auto-generated)
└── build/                             # Plugin build output (auto-generated)
```

## References
- https://github.com/banach-space/llvm-tutor?tab=readme-ov-file#helloworld-your-first-pass
