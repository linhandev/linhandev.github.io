# KMP/OHOS Best Practices

## Compiler Development Best Practices

### Kotlin Native Compiler Development
- Use incremental builds for faster development cycles (avoid `clean` unless absolutely necessary)
- Always stop Gradle daemon between major changes: `./gradlew --stop`
- Build only what's needed: target specific tasks like `:kotlin-native:dist` instead of full builds when possible
- Preserve temporary files during debugging: use `-Xtemporary-files-dir=/tmp/kn_test_temp`

### OHOS Integration Patterns
- Use DevEco Studio SDK's LLVM for OHOS-specific libraries when encountering linking errors
- Handle debug info conflicts by managing runtime debug info appropriately
- Address Werror issues by fixing warnings rather than disabling checks

## Architecture Decisions

### Multiplatform Design
- Place platform-independent code in `commonMain`
- Use `expect`/`actual` for platform-specific implementations
- Maintain clear separation between shared and platform-specific code
- Use abstraction layers for platform-specific services

### Testing Strategy
- Test on macOS first (fast local testing) before OHOS deployment
- Use the two-stage approach: local testing followed by device testing
- Preserve intermediate files for debugging: `-Xtemporary-files-dir`
- Verify executable architecture before device deployment

## Performance Considerations

### Shared Code Optimization
- Avoid heavy computations in shared code that could impact UI responsiveness
- Be mindful of threading differences between platforms
- Optimize for the constraints of each target platform

### Resource Management
- Minimize platform-specific dependencies in shared modules
- Use lazy initialization where appropriate for performance
- Profile memory usage across all target platforms

## Common Pitfalls to Avoid

1. **Gradle Daemon Issues**: Always stop daemons when switching between major configurations
2. **Platform Libraries**: Ensure OHOS platform libraries are built before compiling OHOS targets
3. **Debug Info Conflicts**: Manage runtime debug info carefully to avoid module issues
4. **API Compatibility**: Test thoroughly across all target platforms after changes
5. **Threading Models**: Account for differences in threading between platforms

## Development Workflow

### Iterative Development
1. Make code changes
2. Perform incremental build
3. Test compilation with simple test cases
4. Deploy and test on target platform
5. Iterate based on findings

### Verification Checklist
- [ ] Compiler builds successfully
- [ ] Simple test file compiles for target platform
- [ ] Generated executable has correct architecture
- [ ] No new linker errors introduced
- [ ] Backward compatibility maintained