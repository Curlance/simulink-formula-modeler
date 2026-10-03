# 开发与问题反馈

请在 Issue 中提供 MATLAB 版本、已安装工具箱、复现步骤、完整错误信息和最小 JSON 示例。模型提取问题请补充模块类型和结构；上传模型前移除个人或业务数据。

在 MATLAB 中切换至仓库根目录，然后运行：

```matlab
run('tests/runAll.m');
```

测试失败或未完成会使运行报错，实际结果写入 `artifacts/tests/<时间戳>/`。完整测试需要 MATLAB、Simulink、Control System Toolbox 和 Symbolic Math Toolbox。

新增模型类型须验证实际参数与连线语义，并与独立手写解析式或 ODE 比较。表达式继续使用受限 parser；不应通过 eval 执行用户输入。不支持的结构须明确报错。

本仓库尚未授予开源许可证；如需再分发或商业使用，请先联系仓库所有者。
