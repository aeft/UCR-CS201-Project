#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {
// This method implements what the pass does
void visitor(Function &F) {
    // TODO implement your algorithm here
}

// New PM implementation
struct LocalValueNumbering : PassInfoMixin<LocalValueNumbering> {
    // Main entry point, takes IR unit to run the pass on (&F) and the
    // corresponding pass manager (to be queried if need be)
    PreservedAnalyses run(Function &F, FunctionAnalysisManager &) {
        visitor(F);
        return PreservedAnalyses::all();
    }

    // Without isRequired returning true, this pass will be skipped for
    // functions decorated with the optnone LLVM attribute. Note that clang
    // -O0 decorates all functions with optnone.
    static bool isRequired() { return true; }
};
}  // namespace

//-----------------------------------------------------------------------------
// New PM Registration
//-----------------------------------------------------------------------------
llvm::PassPluginLibraryInfo getLocalValueNumberingPluginInfo() {
    return {LLVM_PLUGIN_API_VERSION, "LocalValueNumbering", LLVM_VERSION_STRING,
            [](PassBuilder &PB) {
                PB.registerPipelineParsingCallback(
                    [](StringRef Name, FunctionPassManager &FPM,
                       ArrayRef<PassBuilder::PipelineElement>) {
                        if (Name == "local-value-numbering") {
                            FPM.addPass(LocalValueNumbering());
                            return true;
                        }
                        return false;
                    });
            }};
}

// This is the core interface for pass plugins. It guarantees that 'opt' will
// be able to recognize LocalValueNumbering when added to the pass pipeline on
// the command line, i.e. via '-passes=local-value-numbering"
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
    return getLocalValueNumberingPluginInfo();
}
