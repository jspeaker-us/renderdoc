# RenderDoc Injector

自动注入RenderDoc到游戏进程的工具。

## 功能特点

✅ 无需替换d3d11.dll  
✅ 在游戏启动前注入RenderDoc  
✅ 支持命令行参数传递  
✅ 自动查找RenderDoc安装路径  
✅ 支持快捷键截帧（F11/F12/PrtScrn）  

## 编译

1. 在Visual Studio中打开`renderdoc.sln`
2. 将`RenderDocInjector`项目添加到解决方案
3. 编译项目

或者单独编译：
```bash
cl RenderDocInjector.cpp /Fe:RenderDocInjector.exe
```

## 使用方法

### 基本用法

```bash
RenderDocInjector.exe "C:\Games\MyGame.exe"
```

### 带参数启动

```bash
RenderDocInjector.exe "C:\Games\MyGame.exe" -windowed -debug
```

### 指定RenderDoc路径

```bash
set RENDERDOC_PATH=C:\Program Files\RenderDoc
RenderDocInjector.exe "C:\Games\MyGame.exe"
```

## RenderDoc DLL查找顺序

注入器会按以下顺序查找`renderdoc.dll`：

1. **当前目录** - 运行注入器的目录
2. **注入器所在目录** - RenderDocInjector.exe的目录
3. **注册表路径** - RenderDoc安装目录（从`HKEY_CLASSES_ROOT\RenderDoc.RDCCapture.1`读取）
4. **环境变量** - `RENDERDOC_PATH`指定的目录

## 快捷键

游戏运行后，可以使用以下快捷键：

- **F11** - 切换活动窗口（多窗口时）
- **F12 或 PrtScrn** - 捕获当前帧

## 创建快捷方式

为方便使用，可以创建游戏快捷方式：

1. 右键桌面 → 新建 → 快捷方式
2. 输入路径：
   ```
   "C:\Path\To\RenderDocInjector.exe" "C:\Games\MyGame.exe"
   ```
3. 命名为：MyGame (with RenderDoc)

## 批处理脚本示例

创建`LaunchWithRenderDoc.bat`：

```batch
@echo off
set GAME_PATH=C:\Games\MyGame\MyGame.exe
set GAME_ARGS=-windowed -lowmemory

echo Launching game with RenderDoc...
RenderDocInjector.exe "%GAME_PATH%" %GAME_ARGS%

if errorlevel 1 (
    echo Failed to launch game!
    pause
)
```

## 故障排除

### 注入失败

检查：
- renderdoc.dll是否存在且路径正确
- 游戏exe是否存在
- 是否有足够权限（某些游戏需要管理员权限）

### 找不到renderdoc.dll

解决方法：
1. 复制renderdoc.dll到注入器同目录
2. 设置RENDERDOC_PATH环境变量
3. 确保RenderDoc已正确安装

### 游戏崩溃

可能原因：
- 游戏有反作弊保护
- renderdoc.dll版本不匹配（32位/64位）
- 游戏使用了不支持的API

## 技术细节

### 注入原理

1. 以**挂起状态**创建游戏进程（`CREATE_SUSPENDED`）
2. 在游戏主线程执行前，通过`CreateRemoteThread`调用`LoadLibraryW`
3. 注入完成后恢复进程执行
4. RenderDoc的`DllMain`会自动注册钩子

### 优势

与替换d3d11.dll相比：
- ✅ 不需要导出43个D3D11函数
- ✅ 不会与其他Mod/工具冲突
- ✅ 游戏加载真正的系统d3d11.dll
- ✅ RenderDoc钩子在游戏初始化前就位

## 与3DMigoto对比

| 特性 | RenderDoc注入器 | 3DMigoto |
|------|----------------|----------|
| 方式 | 远程线程注入 | DLL替换 + LoadLibrary钩子 |
| 兼容性 | 更好 | 可能冲突 |
| 复杂度 | 简单 | 复杂 |
| 功能 | 仅注入RenderDoc | 完整的Mod框架 |

## License

与RenderDoc相同的MIT License。

