# QuickLauncher 公式计算器

输入 `calc (1 + 2) * 3` 并选择插件，即计算并复制结果。支持小数、科学计数法、括号、正负号、`+`、`-`、`*`（或 `×`）、`/`（或 `÷`）、`%` 取模、`^` / `**` 整数幂；例如 `calc 12.5%5`、`calc 2^10`。运算以有理数进行，结果最多保留 12 位小数，按四舍五入（中点远离零）输出；低于显示精度的非零结果会报错。指数限于 -100 到 100，公式及中间结果也有限额。

也可以先在其他应用中选中公式，再打开 QuickLauncher，输入 `calc` 并选择插件执行。QuickLauncher 在执行时尝试读取先前应用的选中文字并传给插件；此功能需要在 macOS 中按需授予 QuickLauncher 辅助功能权限，且目标应用需支持通过辅助功能提供选区。无法读取时，可将公式手动粘贴到 `calc ` 后。插件自己不会读取剪贴板或其他应用，成功结果由 QuickLauncher 显示并写入剪贴板。插件不会联网、执行公式中的代码或运行 shell 命令。

需要支持 `input: "arguments"` 和按需读取选区的 QuickLauncher 版本，以及可用的 Ruby 运行环境。通过应用的“插件 → 发现插件”搜索 `peiel/quicklauncher-calculator-plugin`，审查后安装并启用；也可以从插件展示站一键打开应用进行审核。

## 协议和测试

从标准输入读取 JSON `{"version":1,"arguments":"(1 + 2) * 3"}`，向标准输出写入 `{"version":1,"action":"copyAndShow","text":"9"}`；错误返回 `error`。运行 `ruby tests/calculator_test.rb` 做不涉及界面的测试。MIT 许可证，详见 LICENSE。
