# OHOS Integration with KMP

KMP shared modules consumed by OHOS; shared business logic, ArkTS frontend. Setup: build KMP as library, add to OHOS deps, call via interfaces. Issues: API compatibility, threading, lifecycle. Best: separate shared/platform code, abstraction layers, test all targets. Related: [kmp-structure.md](../kmp-foundations/kmp-structure.md).