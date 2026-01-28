# CS201 Project 2: Local Value Numbering

This project implements a Local Value Numbering (LVN) optimization pass for LLVM.

## Task Description

Implement basic local value numbering (LVN) to identify redundant computations:

**Goal:** Find all LVN-identifiable redundant computations in a given function

**Requirements:**
- Only **identify** redundant computations (no need to remove them)
- Handle basic scenario only:
  - All variables are local variables
  - All variables are primitive data types
  - No branching statements (no if-else, no loops)
  - Only redundant arithmetic operations: `+`, `-`, `*`, `/`
    - Note: `/` is broken into `UDiv` (unsigned) and `SDiv` (signed)
  - No need to handle commutative cases (e.g., `a + b` vs `b + a`)

**Tips:**
- Since removal is not required, variable renaming is not necessary
- Load/store operations in IR can be treated as copy operations (e.g., `b = a`)

**Success Criterion:**
- Your implementation should pass all tests: `./test.sh`

## API Hints

**Useful LLVM APIs:**
- `for (BasicBlock &bb : F)` - Iterate over basic blocks in function
- `for (Instruction &inst : bb)` - Iterate over instructions in basic block
- `inst.getOpcode()` - Get instruction opcode (returns `int`)
  - Compare with instruction constants (e.g., `Instruction::Add`, `Instruction::Store`, etc.)
- `inst.getOperand(i)` - Get the i-th operand (returns `Value*`)

**Key concept:** In LLVM, an Instruction is a Value. `&inst` denotes the SSA value defined by the instruction (the `a` in `a = b + c`), while `op0` and `op1` are `Value*` referring to its operands (`b` and `c`). These pointers have stable identity for comparison.

```cpp
void visitor(Function &F) {
	for (BasicBlock& basicBlock: F) {
		for (Instruction& inst: basicBlock) {
			if(Instruction::Add == inst.getOpcode()) {
				Value *op0 = inst.getOperand(0);
				Value *op1 = inst.getOperand(1);
				errs() << &inst << " = " << op0 << " + " << op1 << "\n";
			}
			// ...
		}
	}
}
```
Note: This is just a basic example. See **Output** section below for the actual required format.

**Useful data structures:**
- `std::map<Value*, int>` - Track value numbers for variables
- Similarly, you need a map to track expressions to value numbers (you may need to define a custom data structure for expression)

**Output:**
- Use `errs() << "Hello world" << '\n'` to print output
- Print format: `<LLVM IR instruction>    <value number info>`
  - For load/store: `<vn> = <vn>` (e.g., `1 = 1`)
  - For arithmetic: `<result_vn> = <op1_vn> <op> <op2_vn>` (e.g., `3 = 1 add 2`)
  - Mark redundant: append `(redundant)` at the end
- Note: Your output may show `ptr` or `i32*` depending on LLVM version (both are fine; test script handles this)

**Example:**
- Input: `./test/test0.c`
- Expected output: `./test/expected/test0.txt`

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
LocalValueNumbering.cpp
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
project2/
├── LocalValueNumbering.cpp         # Your implementation (edit this!)
├── CMakeLists.txt                  # CMake build configuration
├── test.sh                         # Build and test script
├── README.md                       # This file
├── test/
│   ├── test0.c - test6.c           # Test cases (C source)
│   ├── expected/                   # Expected output for each test
│   └── output/                     # Test output (auto-generated)
└── build/                          # Plugin build output (auto-generated)
```

## References
- https://github.com/banach-space/llvm-tutor?tab=readme-ov-file#helloworld-your-first-pass
