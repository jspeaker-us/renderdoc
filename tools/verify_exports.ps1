# 验证 renderdoc.dll 导出表的 PowerShell 脚本
# 使用方法: .\verify_exports.ps1

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "RenderDoc DLL 导出表验证脚本" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 查找 dumpbin.exe
$dumpbin = $null
$possiblePaths = @(
    "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\*\bin\HostX64\x64\dumpbin.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\*\bin\HostX64\x64\dumpbin.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC\*\bin\HostX64\x64\dumpbin.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\*\VC\Tools\MSVC\*\bin\HostX64\x64\dumpbin.exe"
)

foreach ($pattern in $possiblePaths) {
    $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $dumpbin = $found.FullName
        break
    }
}

if (-not $dumpbin) {
    Write-Host "❌ 未找到 dumpbin.exe" -ForegroundColor Red
    Write-Host "   请确保已安装 Visual Studio 并包含 C++ 工具" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ 找到 dumpbin: $dumpbin" -ForegroundColor Green
Write-Host ""

# 查找 renderdoc.dll
$dllPath = "x64\Development\renderdoc.dll"
if (-not (Test-Path $dllPath)) {
    $dllPath = "x64\Release\renderdoc.dll"
}

if (-not (Test-Path $dllPath)) {
    Write-Host "❌ 未找到 renderdoc.dll" -ForegroundColor Red
    Write-Host "   请先编译项目，查找路径：" -ForegroundColor Yellow
    Write-Host "   - x64\Development\renderdoc.dll" -ForegroundColor Yellow
    Write-Host "   - x64\Release\renderdoc.dll" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ 找到 DLL: $dllPath" -ForegroundColor Green
$dllInfo = Get-Item $dllPath
Write-Host "  文件大小: $([math]::Round($dllInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
Write-Host "  修改时间: $($dllInfo.LastWriteTime)" -ForegroundColor Gray
Write-Host ""

Write-Host "正在分析导出表..." -ForegroundColor Cyan
Write-Host ""

# 获取导出表
$exports = & $dumpbin /EXPORTS $dllPath | Out-String

# 分析各类函数
$rdxFunctions = ($exports | Select-String -Pattern "RDX_" -AllMatches).Matches.Count
$renderdocFunctions = ($exports | Select-String -Pattern "RENDERDOC_[A-Za-z]" -AllMatches).Matches.Count
$internalFunctions = ($exports | Select-String -Pattern "INTERNAL_" -AllMatches).Matches.Count
$vkLayerFunctions = ($exports | Select-String -Pattern "VK_LAYER_RENDERDOC_" -AllMatches).Matches.Count
$dllFunctions = ($exports | Select-String -Pattern "Dll(GetClassObject|CanUnloadNow)" -AllMatches).Matches.Count

# 显示结果
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "导出表分析结果" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$success = $true

# RDX_ 函数（应该有 53 个）
if ($rdxFunctions -eq 53) {
    Write-Host "✓ RDX_* 函数: $rdxFunctions / 53" -ForegroundColor Green
} elseif ($rdxFunctions -gt 0) {
    Write-Host "⚠ RDX_* 函数: $rdxFunctions / 53 (数量不符)" -ForegroundColor Yellow
    $success = $false
} else {
    Write-Host "❌ RDX_* 函数: $rdxFunctions / 53 (未找到)" -ForegroundColor Red
    $success = $false
}

# RENDERDOC_ 函数（应该为 0）
if ($renderdocFunctions -eq 0) {
    Write-Host "✓ RENDERDOC_* 函数: $renderdocFunctions (已移除旧前缀)" -ForegroundColor Green
} else {
    Write-Host "❌ RENDERDOC_* 函数: $renderdocFunctions (仍有旧前缀！)" -ForegroundColor Red
    Write-Host "   这意味着 .def 文件可能未生效，或者源代码中仍有 __declspec(dllexport)" -ForegroundColor Yellow
    $success = $false
}

# INTERNAL_ 函数（应该有 9 个）
if ($internalFunctions -eq 9) {
    Write-Host "✓ INTERNAL_* 函数: $internalFunctions / 9" -ForegroundColor Green
} else {
    Write-Host "⚠ INTERNAL_* 函数: $internalFunctions / 9 (数量不符)" -ForegroundColor Yellow
    $success = $false
}

# VK_LAYER_ 函数（应该有 7 个）
if ($vkLayerFunctions -eq 7) {
    Write-Host "✓ VK_LAYER_RENDERDOC_* 函数: $vkLayerFunctions / 7" -ForegroundColor Green
} else {
    Write-Host "⚠ VK_LAYER_RENDERDOC_* 函数: $vkLayerFunctions / 7 (数量不符)" -ForegroundColor Yellow
    $success = $false
}

# COM 函数（应该有 2 个）
if ($dllFunctions -eq 2) {
    Write-Host "✓ DLL 接口函数: $dllFunctions / 2" -ForegroundColor Green
} else {
    Write-Host "⚠ DLL 接口函数: $dllFunctions / 2 (数量不符)" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""
$totalExpected = 53 + 0 + 9 + 7 + 2
$totalActual = $rdxFunctions + $renderdocFunctions + $internalFunctions + $vkLayerFunctions + $dllFunctions
Write-Host "总计导出函数: $totalActual / $totalExpected" -ForegroundColor $(if ($totalActual -eq $totalExpected) { "Green" } else { "Yellow" })
Write-Host ""

# 显示关键函数
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "关键导出函数列表" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "RDX_* 函数 (前 10 个):" -ForegroundColor White
$exports | Select-String -Pattern "\s+RDX_\w+" -AllMatches | 
    ForEach-Object { $_.Matches.Value.Trim() } | 
    Select-Object -First 10 | 
    ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

Write-Host ""

# 检查是否还有 RENDERDOC_ 函数
if ($renderdocFunctions -gt 0) {
    Write-Host "⚠ 仍然存在的 RENDERDOC_* 函数:" -ForegroundColor Yellow
    $exports | Select-String -Pattern "\s+RENDERDOC_\w+" -AllMatches | 
        ForEach-Object { $_.Matches.Value.Trim() } | 
        Select-Object -First 10 | 
        ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host ""
}

# 最终结论
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "验证结论" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($success -and $renderdocFunctions -eq 0 -and $rdxFunctions -eq 53) {
    Write-Host "✅ 导出表修改成功！" -ForegroundColor Green
    Write-Host "   - 所有 RENDERDOC_* 函数已改为 RDX_* 前缀" -ForegroundColor Green
    Write-Host "   - 旧前缀已完全移除" -ForegroundColor Green
    Write-Host "   - INTERNAL_* 和 VK_LAYER_* 函数保持不变" -ForegroundColor Green
} elseif ($renderdocFunctions -gt 0) {
    Write-Host "❌ 导出表修改未完全生效" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能的原因：" -ForegroundColor Yellow
    Write-Host "1. 项目未完全重新编译（尝试 Clean + Rebuild）" -ForegroundColor Yellow
    Write-Host "2. apidefs.h 修改未生效（检查 RENDERDOC_EXPORT_API 定义）" -ForegroundColor Yellow
    Write-Host "3. 其他文件中还有 __declspec(dllexport)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "建议操作：" -ForegroundColor Cyan
    Write-Host "1. 执行 Clean Solution" -ForegroundColor Cyan
    Write-Host "2. 确认修改：" -ForegroundColor Cyan
    Write-Host "   - renderdoc\api\replay\apidefs.h (第 80 行)" -ForegroundColor Cyan
    Write-Host "   - renderdoc\os\win32\win32_process.cpp" -ForegroundColor Cyan
    Write-Host "   - renderdoc\os\win32\comexport.def" -ForegroundColor Cyan
    Write-Host "3. 执行 Rebuild Solution" -ForegroundColor Cyan
} else {
    Write-Host "⚠ 导出表部分正确，但函数数量不符合预期" -ForegroundColor Yellow
    Write-Host "   请检查 comexport.def 文件是否包含所有必要的函数" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "详细导出表已保存到: export_verification.txt" -ForegroundColor Gray
$exports | Out-File -FilePath "export_verification.txt" -Encoding UTF8
Write-Host ""

# 返回退出码
if ($success -and $renderdocFunctions -eq 0 -and $rdxFunctions -eq 53) {
    exit 0
} else {
    exit 1
}

