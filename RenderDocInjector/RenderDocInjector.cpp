/******************************************************************************
 * RenderDoc Injector
 * 
 * 功能：
 * 1. 创建游戏进程（挂起状态）
 * 2. 在游戏初始化前注入 RenderDoc DLL
 * 3. 恢复游戏进程执行
 * 
 * 使用方法：
 *   RenderDocInjector.exe <游戏路径> [参数]
 *   RenderDocInjector.exe "C:\Games\MyGame.exe" -windowed
 * 
 * 配置 DLL 名称：
 *   修改下面的 DLL_NAME 宏来更改要注入的 DLL 名称
 * 
 *   示例：
 *     #define DLL_NAME L"rdx.dll"         // 使用 rdx.dll
 *     #define DLL_NAME L"custom.dll"      // 使用自定义名称
 *     #define DLL_NAME L"renderdoc.dll"   // 使用原始名称
 ******************************************************************************/

#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <string>

// ============================================================================
// 配置
// ============================================================================
#define LOG_FILE "renderdoc_injector.log"

// DLL 名称配置（可修改以使用不同的名称）
// 修改这里来改变要注入的 DLL 名称
#define DLL_NAME L"rdxx.dll"

// ============================================================================
// 日志函数
// ============================================================================
void Log(const char* format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    
    // 输出到控制台
    printf("%s\n", buffer);
    
    // 输出到文件
    FILE* f = fopen(LOG_FILE, "a");
    if (f) {
        fprintf(f, "%s\n", buffer);
        fclose(f);
    }
}

void LogW(const wchar_t* format, ...) {
    wchar_t buffer[1024];
    va_list args;
    va_start(args, format);
    vswprintf(buffer, sizeof(buffer) / sizeof(wchar_t), format, args);
    va_end(args);
    
    wprintf(L"%s\n", buffer);
    
    FILE* f = fopen(LOG_FILE, "a");
    if (f) {
        fwprintf(f, L"%s\n", buffer);
        fclose(f);
    }
}

// ============================================================================
// 查找RenderDoc DLL (使用宏定义的名称)
// ============================================================================
bool FindRenderDocDLL(wchar_t* outPath, size_t maxLen) {
    Log("Searching for DLL: %S", DLL_NAME);
    
    // 1. 尝试当前目录
    if (GetFileAttributesW(DLL_NAME) != INVALID_FILE_ATTRIBUTES) {
        wchar_t currentDir[MAX_PATH];
        GetCurrentDirectoryW(MAX_PATH, currentDir);
        swprintf(outPath, maxLen, L"%s\\%s", currentDir, DLL_NAME);
        Log("Found in current directory");
        return true;
    }
    
    // 2. 尝试注入器同目录
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(NULL, exePath, MAX_PATH);
    wchar_t* lastSlash = wcsrchr(exePath, L'\\');
    if (lastSlash) {
        *lastSlash = L'\0';
        swprintf(outPath, maxLen, L"%s\\%s", exePath, DLL_NAME);
        if (GetFileAttributesW(outPath) != INVALID_FILE_ATTRIBUTES) {
            Log("Found in injector directory");
            return true;
        }
    }
    
    // 3. 尝试从注册表获取RenderDoc安装路径
    HKEY key;
    if (RegOpenKeyExW(HKEY_CLASSES_ROOT, L"RenderDoc.RDCCapture.1\\DefaultIcon", 
                      0, KEY_READ, &key) == ERROR_SUCCESS) {
        DWORD size = (DWORD)maxLen * sizeof(wchar_t);
        DWORD type;
        if (RegQueryValueExW(key, NULL, NULL, &type, (LPBYTE)outPath, &size) == ERROR_SUCCESS) {
            RegCloseKey(key);
            
            // 提取目录并添加 DLL 名称
            wchar_t* slash = wcsrchr(outPath, L'\\');
            if (slash) {
                *(slash + 1) = L'\0';
                wcscat(outPath, DLL_NAME);
                if (GetFileAttributesW(outPath) != INVALID_FILE_ATTRIBUTES) {
                    Log("Found in RenderDoc installation directory");
                    return true;
                }
            }
        }
        RegCloseKey(key);
    }
    
    // 4. 尝试环境变量
    wchar_t envPath[MAX_PATH];
    if (GetEnvironmentVariableW(L"RENDERDOC_PATH", envPath, MAX_PATH) > 0) {
        swprintf(outPath, maxLen, L"%s\\%s", envPath, DLL_NAME);
        if (GetFileAttributesW(outPath) != INVALID_FILE_ATTRIBUTES) {
            Log("Found via RENDERDOC_PATH environment variable");
            return true;
        }
    }
    
    return false;
}

// ============================================================================
// 远程线程注入DLL
// ============================================================================
bool InjectDLL(HANDLE hProcess, const wchar_t* dllPath) {
    Log("Injecting DLL: %S", dllPath);
    
    // 1. 在目标进程中分配内存存储DLL路径
    size_t pathSize = (wcslen(dllPath) + 1) * sizeof(wchar_t);
    void* remotePath = VirtualAllocEx(hProcess, NULL, pathSize, 
                                      MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!remotePath) {
        Log("Failed to allocate memory in target process: %d", GetLastError());
        return false;
    }
    
    // 2. 将DLL路径写入目标进程
    SIZE_T written;
    if (!WriteProcessMemory(hProcess, remotePath, dllPath, pathSize, &written)) {
        Log("Failed to write DLL path to target process: %d", GetLastError());
        VirtualFreeEx(hProcess, remotePath, 0, MEM_RELEASE);
        return false;
    }
    
    // 3. 获取LoadLibraryW函数地址
    HMODULE hKernel32 = GetModuleHandleW(L"kernel32.dll");
    if (!hKernel32) {
        Log("Failed to get kernel32.dll handle");
        VirtualFreeEx(hProcess, remotePath, 0, MEM_RELEASE);
        return false;
    }
    
    FARPROC loadLibraryW = GetProcAddress(hKernel32, "LoadLibraryW");
    if (!loadLibraryW) {
        Log("Failed to get LoadLibraryW address");
        VirtualFreeEx(hProcess, remotePath, 0, MEM_RELEASE);
        return false;
    }
    
    // 4. 创建远程线程执行LoadLibraryW
    HANDLE hThread = CreateRemoteThread(hProcess, NULL, 0,
                                       (LPTHREAD_START_ROUTINE)loadLibraryW,
                                       remotePath, 0, NULL);
    if (!hThread) {
        Log("Failed to create remote thread: %d", GetLastError());
        VirtualFreeEx(hProcess, remotePath, 0, MEM_RELEASE);
        return false;
    }
    
    Log("Remote thread created, waiting for completion...");
    
    // 5. 等待线程完成
    WaitForSingleObject(hThread, INFINITE);
    
    // 6. 检查返回值（LoadLibraryW的返回值是模块句柄）
    DWORD exitCode;
    GetExitCodeThread(hThread, &exitCode);
    
    CloseHandle(hThread);
    VirtualFreeEx(hProcess, remotePath, 0, MEM_RELEASE);
    
    if (exitCode == 0) {
        Log("LoadLibraryW failed in target process");
        return false;
    }
    
    Log("DLL injected successfully! Module handle: 0x%p", (void*)exitCode);
    return true;
}

// ============================================================================
// 创建进程并注入
// ============================================================================
bool CreateProcessAndInject(const wchar_t* exePath, const wchar_t* cmdLine, 
                           const wchar_t* workingDir, const wchar_t* dllPath) {
    LogW(L"Creating process: %s", exePath);
    LogW(L"Command line: %s", cmdLine ? cmdLine : L"(none)");
    LogW(L"Working directory: %s", workingDir ? workingDir : L"(same as exe)");
    
    // 1. 创建挂起的进程
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = { 0 };
    
    wchar_t cmdLineCopy[4096] = { 0 };
    if (cmdLine && wcslen(cmdLine) > 0) {
        wcscpy(cmdLineCopy, cmdLine);
    }
    
    BOOL success = CreateProcessW(
        exePath,                    // 应用程序路径
        cmdLine ? cmdLineCopy : NULL, // 命令行
        NULL,                       // 进程安全属性
        NULL,                       // 线程安全属性
        FALSE,                      // 不继承句柄
        CREATE_SUSPENDED,           // 创建标志：挂起
        NULL,                       // 环境变量
        workingDir,                 // 工作目录
        &si,                        // 启动信息
        &pi                         // 进程信息
    );
    
    if (!success) {
        Log("Failed to create process: %d", GetLastError());
        return false;
    }
    
    Log("Process created successfully (PID: %d)", pi.dwProcessId);
    Log("Process is suspended, injecting DLL...");
    
    // 2. 注入DLL
    bool injected = InjectDLL(pi.hProcess, dllPath);
    
    if (!injected) {
        Log("Failed to inject DLL, terminating process...");
        TerminateProcess(pi.hProcess, 1);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        return false;
    }
    
    // 3. 恢复进程执行
    Log("Resuming process...");
    ResumeThread(pi.hThread);
    
    Log("========================================");
    Log("SUCCESS!");
    Log("Game launched with RenderDoc injected!");
    Log("========================================");
    Log("Hotkeys:");
    Log("  F11        - Cycle active window");
    Log("  F12/PrtScr - Capture frame");
    Log("========================================");
    
    // 4. 清理句柄（不等待进程结束）
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    
    return true;
}

// ============================================================================
// 主函数
// ============================================================================
int wmain(int argc, wchar_t* argv[]) {
    wprintf(L"========================================\n");
    wprintf(L"RenderDoc Injector v1.0\n");
    wprintf(L"========================================\n\n");
    
    // 清空日志文件
    FILE* f = fopen(LOG_FILE, "w");
    if (f) fclose(f);
    
    // 1. 检查参数
    if (argc < 2) {
        wprintf(L"Usage: RenderDocInjector.exe <game.exe> [arguments]\n");
        wprintf(L"\nExamples:\n");
        wprintf(L"  RenderDocInjector.exe \"C:\\Games\\MyGame.exe\"\n");
        wprintf(L"  RenderDocInjector.exe \"C:\\Games\\MyGame.exe\" -windowed\n");
        wprintf(L"  RenderDocInjector.exe MyGame.exe --debug\n");
        wprintf(L"\nEnvironment Variables:\n");
        wprintf(L"  RENDERDOC_PATH - Path to RenderDoc installation directory\n");
        return 1;
    }
    
    const wchar_t* exePath = argv[1];
    
    // 2. 构建命令行
    std::wstring cmdLine = L"\"";
    cmdLine += exePath;
    cmdLine += L"\"";
    
    for (int i = 2; i < argc; i++) {
        cmdLine += L" ";
        // 如果参数包含空格，加引号
        if (wcschr(argv[i], L' ')) {
            cmdLine += L"\"";
            cmdLine += argv[i];
            cmdLine += L"\"";
        } else {
            cmdLine += argv[i];
        }
    }
    
    // 3. 确定工作目录（游戏所在目录）
    wchar_t workingDir[MAX_PATH];
    wcscpy(workingDir, exePath);
    wchar_t* lastSlash = wcsrchr(workingDir, L'\\');
    if (lastSlash) {
        *lastSlash = L'\0';
    } else {
        GetCurrentDirectoryW(MAX_PATH, workingDir);
    }
    
    // 4. 查找RenderDoc DLL
    wchar_t dllPath[MAX_PATH];
    if (!FindRenderDocDLL(dllPath, MAX_PATH)) {
        wprintf(L"ERROR: Cannot find %s\n\n", DLL_NAME);
        wprintf(L"Please ensure the DLL is in one of these locations:\n");
        wprintf(L"  1. Current directory\n");
        wprintf(L"  2. Same directory as RenderDocInjector.exe\n");
        wprintf(L"  3. RenderDoc installation directory\n");
        wprintf(L"  4. Path specified in RENDERDOC_PATH environment variable\n");
        return 1;
    }
    
    LogW(L"Found RenderDoc DLL at: %s", dllPath);
    
    // 5. 验证文件存在
    if (GetFileAttributesW(exePath) == INVALID_FILE_ATTRIBUTES) {
        wprintf(L"ERROR: Game executable not found: %s\n", exePath);
        return 1;
    }
    
    // 6. 执行注入
    bool success = CreateProcessAndInject(exePath, cmdLine.c_str(), workingDir, dllPath);
    
    if (!success) {
        wprintf(L"\nERROR: Failed to inject RenderDoc. See %s for details.\n", 
                TEXT(LOG_FILE));
        return 1;
    }
    
    wprintf(L"\nLog saved to: %s\n", TEXT(LOG_FILE));
    return 0;
}

