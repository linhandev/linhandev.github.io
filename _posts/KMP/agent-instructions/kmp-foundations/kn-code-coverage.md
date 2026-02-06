# Kotlin/Native Code Coverage Guide

This guide explains how to implement and analyze code coverage for Kotlin/Native applications based on the analysis of KMP blog posts.

## Understanding Code Coverage in KN

KN code coverage is implemented using LLVM's gcov infrastructure rather than Kotlin IR instrumentation, primarily because:
- LLVM gcov is a mature native profiling tool with simpler integration
- KN IR instrumentation would require significant implementation effort
- LLVM IR is closer to native execution, though further from source Kotlin

## Implementation Approach

### Compiler Configuration
Enable coverage by adding these compiler arguments:

```
freeCompilerArgs += "-Xadd-light-debug=enable"
freeCompilerArgs += "-Xbinary=coverage=true"
```

### How It Works
1. **Compile-time instrumentation**: The GCOVProfilerPass inserts counters into LLVM IR
2. **Runtime collection**: Execution counts are stored in `@__llvm_gcov_ctr` arrays
3. **Data persistence**: Results are written to .gcda files at runtime
4. **Analysis**: Tools correlate .gcda data with .gcno notes to show coverage

### Example of Instrumentation
Before instrumentation:
```llvm
define dso_local i32 @main() #0 {
  %1 = alloca i32, align 4
  %2 = alloca i8, align 1
  store i32 0, i32* %1, align 4
  %3 = call i32 @rand()
  %4 = srem i32 %3, 2
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %6, label %7
}
```

After instrumentation:
```llvm
@__llvm_gcov_ctr = internal global [2 x i64] zeroinitializer

define dso_local i32 @main() #0 {
  ; ... existing code ...
  br i1 %5, label %6, label %9

6:                                                ; preds = %0
  %7 = load i64, i64* getelementptr inbounds ([2 x i64], [2 x i64]* @__llvm_gcov_ctr, i64 0, i64 0), align 8
  %8 = add i64 %7, 1
  store i64 %8, i64* getelementptr inbounds ([2 x i64], [2 x i64]* @__llvm_gcov_ctr, i64 0, i64 0), align 8
  ; ... rest of code ...
}
```

## Runtime Integration

### Linking Requirements
Link the `libclang_rt.profile.a` library which contains:
- Coverage result writing functions (`__gcov_dump`)
- Profile runtime functions (used for PGO)

### HAP Integration
Trigger coverage dump at appropriate points in your application:

```cpp
extern "C" void __gcov_dump(void) __attribute__((weak));

if (__gcov_dump) {
    __gcov_dump();
}
```

### File Location Configuration
- `GCOV_PREFIX`: Set to a writable path for coverage files
- `GCOV_PREFIX_STRIP`: Strip path prefixes to avoid deep directory structures
- Files are typically written as:
  - `.gcno` files in the build directory (where the build ran)
  - `.gcda` files in `/data/app/el2/100/base/[bundle-name]/files/gcov/` on device

## Coverage Analysis Tools

### llvm-cov
Basic analysis tool that requires source code at the paths referenced in the .gcno files:

```bash
# Run in directory containing .gcda and .gcno files
llvm-cov gcov -b -f libc2k.gcda
```

Sample output interpretation:
- `-`: Line not considered executable (comments, labels, etc.)
- `#####`: Executable line that was not executed
- Numbers: Execution count for executed lines

### gcovr
More user-friendly tool with multiple output formats:

#### HTML Report
```bash
python -m gcovr --html --html-details --output out/coverage.html --root /source/root/ \
  --gcov-ignore-errors=source_not_found \
  --gcov-ignore-errors=output_error \
  --gcov-ignore-errors=no_working_dir_found [path-containing-gcno-gcda]
```

#### JSON Report
```bash
python -m gcovr --json --root ./source/root/ \
  --gcov-ignore-errors=source_not_found \
  --gcov-ignore-errors=output_error \
  --gcov-ignore-errors=no_working_dir_found [path-containing-gcno-gcda]
```

### lcov
Provides enhanced reporting and ability to merge multiple runs:

#### Basic Capture
```bash
lcov --gcov-tool /tmp/llvm_cov_wrapper.sh \
     --ignore-errors format,empty,inconsistent \
     --function-coverage \
     --branch-coverage \
     --capture \
     --directory . \
     --output-file coverage.info
```

#### Merging Multiple Runs
```bash
lcov --add-tracefile coverage1.info \
     --add-tracefile coverage2.info \
     --ignore-errors format,inconsistent \
     --function-coverage \
     --branch-coverage \
     --output-file coverage_merged.info
```

## Coverage Metrics Explained

### lcov Output Format
- `SF`: Source File path
- `FNL`: Function Line number (function defined on this line)
- `FNA`: Function Name and attributes
- `FNF`: Functions Found (total functions in source)
- `FNH`: Functions Hit (executed functions)
- `BRDA`: Branch Data (line, branch group, branch index, execution count)
- `BRF`: Branches Found (total branches)
- `BRH`: Branches Hit (covered branches)
- `DA`: Data (line number: execution count)
- `LF`: Lines Found (total executable lines)
- `LH`: Lines Hit (covered lines)

## Edge Cases and Limitations

### Known Limitations
- **Inline functions**: Coverage mapping can be complex (though jacoco has addressed this)
- **Exception handling**: Complex to map accurately
- **Lambda expressions**: May not map cleanly to source
- **Chained calls**: Coverage attribution may be unclear

### Complex Constructs
Coverage accuracy may vary with:
- Complex control flow structures
- Generic code
- Coroutines
- Multiplatform code with expect/actual

## Advanced Configuration

### Controlling Instrumentation Scope
Currently, instrumentation happens at the module level. Fine-grained control of which parts of code get instrumented may require custom patches.

### Handling Multiple Runs
For applications that run multiple times:

#### Different Directory Approach
```bash
# Each run in separate directory with its own .gcda file
lcov --gcov-tool /tmp/llvm_cov_wrapper.sh \
     --capture \
     --directory run1/ \
     --directory run2/ \
     --directory run3/ \
     --output-file coverage.info
```

#### Single .gcno with Multiple .gcda
```bash
# One .gcno file with multiple .gcda files in different directories
lcov --gcov-tool /tmp/llvm_cov_wrapper.sh \
    --capture \
    --build-directory . \
    --directory run1 \
    --directory run2 \
    --directory run3 \
    --output-file coverage.info
```

## Best Practices

### 1. Coverage Configuration
- Enable coverage only for debug builds to avoid performance impact
- Use appropriate compiler flags for your use case
- Ensure adequate permissions for writing coverage files

### 2. File Management
- Set up proper directory structure for coverage files
- Ensure coverage files are collected after test runs
- Implement cleanup mechanisms to prevent disk space issues

### 3. Reporting
- Generate reports with meaningful thresholds
- Track coverage trends over time
- Focus on critical code paths first

### 4. Interpretation
- Understand that 100% line coverage doesn't guarantee 100% branch coverage
- Pay attention to conditional logic and exception paths
- Consider the difference between "visited" and "fully tested"

## Troubleshooting

### Common Issues
- **Source not found**: Ensure source code is available at paths referenced in .gcno
- **Permission errors**: Verify write permissions to coverage output directories
- **Missing coverage data**: Check that `__gcov_dump()` is being called appropriately

### Debugging Coverage
- Verify .gcda files are being generated
- Check that source paths in .gcno match actual source locations
- Confirm that the application is executing the code paths you expect to cover

## Future Considerations

### Potential Improvements
- Enhanced mapping for Kotlin-specific constructs
- Better integration with KMP testing frameworks
- Improved handling of inline and generated code
- More sophisticated edge case handling

### Research Areas
- Coverage accuracy for complex Kotlin features
- Performance impact minimization
- Integration with CI/CD pipelines