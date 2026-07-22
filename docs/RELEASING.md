# 发布流程

## 版本准备

1. 将根目录 `VERSION` 更新为目标语义化版本，例如 `1.0.1`。
2. 在 `CHANGELOG.md` 顶部补充同版本的发布日期和用户可见变化。
3. 确认 README 中的当前版本和兼容要求保持一致。
4. 如需递增构建号，打包时设置 `BUILD_NUMBER=<整数>`；默认值为 `1`。

## 发布验证

```bash
swift test
swift build --configuration release --product CPAMonitorBar
bash -n scripts/package-universal.sh scripts/create-dmg.sh
```

所有命令必须成功，Swift 文件应继续满足项目级长度和复杂度门禁。

## 生成测试 DMG

```bash
./scripts/package-universal.sh
```

脚本自动完成：

1. 构建 arm64 与 x86_64 Release 产品。
2. 合并 Universal 2 可执行文件并复制所需 Swift Runtime。
3. 从 `VERSION` 写入 `CFBundleShortVersionString`，写入构建号。
4. 应用 ad-hoc 签名并验证签名、架构、rpath 和 Info.plist。
5. 创建、校验并只读挂载 DMG，复核版本、图标、Applications 入口和凭据标记。
6. 删除 App 暂存目录，仅保留 DMG 并输出 SHA-256。

## 安装冒烟测试

1. 在 Apple Silicon 或 Intel 测试主机上打开 DMG。
2. 将 App 拖入 `/Applications`，通过 Finder 正常确认首次启动。
3. 核对设置页应用版本、Keeper URL、登录、开机启动和刷新频率。
4. 核对四个页签、请求事件滚动分页、认证文件额度刷新、Keeper 版本和浏览器入口。
5. 配置全局快捷键，确认面板在鼠标附近唤出且不会超出当前显示器可见区域。
6. 核对面板拖动、置顶、跨 Space 展示和取消置顶行为。
7. 退出并重新打开 App，确认自动恢复登录且置顶状态未保留；点击退出应用，确认会话被注销。

## 正式分发注意事项

当前脚本生成的是 ad-hoc 测试包。面向不受控用户正式分发前，还需要：

- 选择并声明项目许可证。
- 配置稳定的 Bundle Identifier、Developer ID 签名和 Apple 公证。
- 在干净主机上完成安装、升级和卸载验证。
- 发布 DMG 的 SHA-256，并保留对应 `VERSION` 与 Changelog。
