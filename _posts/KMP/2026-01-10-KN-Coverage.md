---
title: Kotlin/Native 覆盖率
categories:
  - KN
tags:
  - KN
  - KMP
  - Hacking
published: false
---

![alt text](../../assets/img/post/2026-01-10-KN-Coverage/2026-01-10T02:57:08.518Z-image.png)

```gcov
        -:    0:Source:main.cpp
        -:    0:Graph:main.gcno
        -:    0:Data:main.gcda
        -:    0:Runs:1
        -:    0:Programs:1
        -:    1:#include <iostream>
        -:    2:#include <cstdlib>
        -:    3:
        -:    4:// Function to demonstrate function call coverage
        4:    5:int calculate(int a, int b, char op) {
        4:    6:    switch (op) {
        -:    7:        case '+':
        1:    8:            return a + b;
        -:    9:        case '-':
        1:   10:            return a - b;
        -:   11:        case '*':
        1:   12:            return a * b;
        -:   13:        case '/':
        1:   14:            if (b != 0) {
        1:   15:                return a / b;
        -:   16:            } else {
    #####:   17:                return 0; // Division by zero
        -:   18:            }
        -:   19:        default:
    #####:   20:            return -1; // Invalid operator
        -:   21:    }
        4:   22:}
        -:   23:
        1:   24:int main(int argc, char* argv[]) {
        1:   25:    int x = 5;
        1:   26:    int y = 3;
        -:   27:    
        -:   28:    // If-else coverage demo
        1:   29:    if (argc > 1) {
        1:   30:        x = std::atoi(argv[1]);
        1:   31:    } else {
    #####:   32:        x = 10;
        -:   33:    }
        -:   34:    
        1:   35:    if (argc > 2) {
        1:   36:        y = std::atoi(argv[2]);
        1:   37:    } else {
    #####:   38:        y = 5;
        -:   39:    }
        -:   40:    
        -:   41:    // Test different operations
        1:   42:    int result1 = calculate(x, y, '+');
        1:   43:    int result2 = calculate(x, y, '-');
        1:   44:    int result3 = calculate(x, y, '*');
        1:   45:    int result4 = calculate(x, y, '/');
        -:   46:    // int result5 = calculate(x, y, '%'); // Invalid operator
        -:   47:    
        1:   48:    std::cout << "Results: " << result1 << " " << result2 << " " 
        1:   49:              << result3 << " " << result4 << std::endl;
        -:   50:    
        1:   51:    return 0;
        -:   52:}
```

| Symbol   | Meaning                | Example                         |
| -------- | ---------------------- | ------------------------------- |
| `#####:` | Not executed (0 times) | Unreached code paths            |
| `-:`     | Not instrumented       | Comments, blank lines, includes |
| `N:`     | Executed N times       | `4:` = executed 4 times         |



freeCompilerArgs += listOf("-Xbinary=coverage=true", "-Xtemporary-files-dir=/tmp/inspect")

除了so还会编出来一个gcno文件