---
title: Compose预览
categories:
  - CMP
tags:
  - CMP
  - Preview
description: 
published: false
---

- Android Studio只支持安卓和common sourceSet中cmp composable的预览
- CMP 1.6曾经在JetBrains Fleet IDE上支持过 iOS sourceSet预览，但是Fleet这个ide日落了
- @Preview 有两个实现，CMP的（org.jetbrains.compose.ui.tooling.preview.Preview）比Jetpack的（androidx.compose.ui.tooling.preview.Preview）只是多了commonMain中预览的能力
- commonMain需要依赖 compose.components.uiToolingPreview，android debug需要依赖 libs.compose.ui.tooling

https://medium.com/@Vierco/previewing-composables-in-kotlin-multiplatform-ce100a8ebb9a
https://developer.android.com/develop/ui/compose/tooling/previews
