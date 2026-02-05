# OHOS Integration with KMP

## Overview
HarmonyOS (OHOS) can integrate with KMP shared modules for cross-platform development.

## Integration Points
- Ability to consume KMP libraries as dependencies
- Access to shared business logic from OHOS applications
- Compatibility with ArkTS frontend framework

## Setup Process
1. Build KMP shared module as a library
2. Include the library in OHOS project dependencies
3. Access shared functions through appropriate interfaces

## Common Issues
- API compatibility between KMP and OHOS versions
- Threading model differences
- Lifecycle management between platforms

## Best Practices
- Maintain clear separation between shared and platform-specific code
- Use abstraction layers for platform-specific services
- Test thoroughly across all target platforms

## Related Topics
- ../kmp-foundations/kmp-structure.md
- ../best-practices/cross-platform-architectures.md