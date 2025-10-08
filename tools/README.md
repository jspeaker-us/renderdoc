# RenderDoc 导出修改工具

本文件夹包含用于修改 `renderdoc.dll` 导出表的工具。

## 核心修改

将导出函数前缀从 `RENDERDOC_*` 改为 `RDX_*`，同时保留 `INTERNAL_*` 和 `VK_LAYER_RENDERDOC_*` 函数。

## 工具说明

### 1. `generate_new_def.py`
生成 `.def` 文件，用于控制 DLL 导出表。

**用法**：
```bash
python generate_new_def.py
```

**输出**：
- 在控制台打印完整的 `.def` 文件内容
- 可重定向到 `renderdoc/os/win32/comexport.def`

### 2. `verify_exports.ps1`
验证编译后的 `renderdoc.dll` 导出表是否符合预期。

**用法**：
```powershell
.\verify_exports.ps1
```

**检查项**：
- ✅ 53 个 `RDX_*` 公共 API 函数
- ✅ `INTERNAL_*` 内部函数
- ✅ `VK_LAYER_RENDERDOC_*` Vulkan 层函数
- ❌ 不应包含原始 `RENDERDOC_*` 函数名

## 修改文件列表

1. **`renderdoc/api/replay/apidefs.h`** (第 81 行)
   ```cpp
   #define RENDERDOC_EXPORT_API  // 留空，禁用自动导出
   ```

2. **`renderdoc/os/win32/comexport.def`**
   - 使用别名语法导出 `RDX_*` 函数
   - 注释掉 `INTERNAL_*` 和 `VK_LAYER_RENDERDOC_*` 导出

3. **保持不变**：
   - `renderdoc/os/win32/win32_process.cpp` - `INTERNAL_*` 函数保留 `__declspec(dllexport)`
   - `renderdoc/driver/vulkan/vk_layer.cpp` - `VK_LAYER_*` 函数保留 `#pragma comment(linker, ...)`

## 导出策略

| 函数类型 | 数量 | 导出方式 | 前缀 |
|---------|------|---------|------|
| 公共 API | 53 | .def 文件别名 | `RDX_*` |
| 内部函数 | 9 | 源代码 `__declspec(dllexport)` | `INTERNAL_*` |
| Vulkan 层 | 7 | 源代码 `#pragma comment` | `VK_LAYER_RENDERDOC_*` |

## 验证方法

编译后运行验证脚本：
```powershell
cd tools
.\verify_exports.ps1
```

或使用 `dumpbin` 手动检查：
```cmd
dumpbin /EXPORTS ..\x64\Development\renderdoc.dll | findstr "RDX_"
```

