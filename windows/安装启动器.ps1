# 安装 TagClip 到开始菜单 / 桌面 / 任务栏（可选）
# 用法：右键此文件 → 「使用 PowerShell 运行」
# 作用：1) 生成启动器 启动TagClip.bat；2) 把启动项固定到开始菜单；3) 在桌面创建快捷方式；4) 固定到任务栏

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ps1 = Join-Path $scriptDir 'TagClip.ps1'
if (-not (Test-Path -LiteralPath $ps1)) {
    Write-Host "错误：找不到 $ps1" -ForegroundColor Red
    Read-Host '按回车退出'
    exit 1
}

# 1) 生成启动器
$bat = Join-Path $scriptDir '启动TagClip.bat'
if (-not (Test-Path -LiteralPath $bat)) {
    $batContent = @(
        '@echo off',
        'rem TagClip 启动器：隐藏黑色控制台窗口运行 TagClip.ps1',
        'setlocal',
        'cd /d "%~dp0"',
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0TagClip.ps1"'
    ) -join "`r`n"
    Set-Content -LiteralPath $bat -Value $batContent -Encoding Default
    Write-Host "已生成启动器：$bat" -ForegroundColor Green
}

# 2) 开始菜单快捷方式
$shell = New-Object -ComObject WScript.Shell
$startMenu = [Environment]::GetFolderPath('Programs')
$lnk = $shell.CreateShortcut((Join-Path $startMenu 'TagClip.lnk'))
$lnk.TargetPath = $bat
$lnk.WorkingDirectory = $scriptDir
$lnk.Description = 'TagClip - 点击复制文件，聊天窗口 Ctrl+V 发送'
$lnk.Save()
Write-Host "已添加到开始菜单：TagClip" -ForegroundColor Green

# 3) 桌面快捷方式
$desktop = [Environment]::GetFolderPath('Desktop')
$lnk2 = $shell.CreateShortcut((Join-Path $desktop 'TagClip.lnk'))
$lnk2.TargetPath = $bat
$lnk2.WorkingDirectory = $scriptDir
$lnk2.Description = 'TagClip - 点击复制文件，聊天窗口 Ctrl+V 发送'
$lnk2.Save()
Write-Host "已在桌面创建快捷方式：TagClip" -ForegroundColor Green

# 4) 固定到任务栏
try {
    $verb = $shell.NameSpace((Split-Path $bat)).ParseName((Split-Path $bat -Leaf))
    $verb.InvokeVerb('taskbarpin') | Out-Null
    Write-Host "已尝试固定到任务栏（Win11 可能需要手动右键固定）" -ForegroundColor Green
} catch {
    Write-Host "固定任务栏失败（可手动右键「启动TagClip.bat」→ 固定到任务栏）" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "完成！现在可以从开始菜单 / 桌面 / 任务栏打开 TagClip。" -ForegroundColor Green
Read-Host '按回车退出'
