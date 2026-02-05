# KMP Shared Module Structure

## Overview
Kotlin Multiplatform (KMP) allows sharing code between Android and iOS platforms through shared modules.

## Directory Structure
```
shared/
├── src/
│   ├── commonMain/
│   │   └── kotlin/
│   │       └── com/example/shared/
│   │           ├── Network.kt
│   │           ├── Repository.kt
│   │           └── Model.kt
│   ├── androidMain/
│   │   └── kotlin/
│   │       └── com/example/
│   │           └── Platform.kt
│   └── iosMain/
│       └── kotlin/
│           └── com/example/
│               └── Platform.kt
```

## Best Practices
- Place platform-independent code in `commonMain`
- Use `expect`/`actual` for platform-specific implementations
- Utilize `actual typealias` for platform-specific types

## Common Pitfalls
- Avoid heavy computations in shared code that could impact UI responsiveness
- Be mindful of threading differences between platforms

## Related Topics
- ../best-practices/kmp-architecture.md
- ../frequent-issues/platform-specific-implementations.md