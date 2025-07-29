
<#
.SYNOPSIS
   自动卸载 SQL Server 和 SSMS
.DESCRIPTION
   此脚本自动检测并卸载所有版本的 SQL Server 和 SSMS
.NOTES
   需要以管理员权限运行
   执行前建议备份重要数据库
#>

# 设置输出编码为UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 设置输入编码为UTF-8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "请以管理员身份运行此脚本" -ForegroundColor Red
    exit
}

# 确认操作
$confirmation = Read-Host "此操作将卸载SQL Server和SSMS，是否继续？(Y/N)"
if ($confirmation -ne 'Y') {
    exit
}

function Uninstall-Program {
    param (
        [string]$displayNamePattern
    )

    $programs = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
            Where-Object { $_.DisplayName -like "*$displayNamePattern*" }

    foreach ($program in $programs) {
        $uninstallString = $program.UninstallString
        if ($uninstallString) {
            Write-Host "正在卸载: $($program.DisplayName)" -ForegroundColor Yellow

            # 处理带参数的卸载命令
            if ($uninstallString -match "msiexec") {
                $productCode = $program.PSChildName
                Start-Process "msiexec.exe" -ArgumentList "/x $productCode /qn /norestart" -Wait
            }
            else {
                Start-Process cmd.exe -ArgumentList "/c $uninstallString /quiet /norestart" -Wait
            }

            Write-Host "已卸载: $($program.DisplayName)" -ForegroundColor Green
        }
    }
}

# 1. 卸载所有 SQL Server 组件
Write-Host "`n正在查找并卸载 SQL Server 组件..." -ForegroundColor Cyan
$sqlComponents = @(
    "SQL Server 2019",
    "SQL Server 2022",
    "SQL Server 2025",
    "SQL Server Management Studio",
    "SQL Server Setup",
    "SQL Server Native Client",
    "Microsoft SQL Server"
)

foreach ($component in $sqlComponents) {
    Uninstall-Program -displayNamePattern $component
}

# 2. 卸载 SSMS
Write-Host "`n正在查找并卸载 SSMS..." -ForegroundColor Cyan
Uninstall-Program -displayNamePattern "SQL Server Management Studio"

# 3. 删除残留文件和注册表项
Write-Host "`n清理残留文件和注册表项..." -ForegroundColor Cyan

# 删除程序文件
$pathsToRemove = @(
    "${env:ProgramFiles}\Microsoft SQL Server",
    "${env:ProgramFiles(x86)}\Microsoft SQL Server",
    "${env:ProgramFiles}\Microsoft SQL Server Management Studio",
    "${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio"
)

foreach ($path in $pathsToRemove) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "已删除文件夹: $path" -ForegroundColor Yellow
    }
}

# 删除注册表项
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server",
    "HKLM:\SOFTWARE\Microsoft\SQL Server",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\SQL Server"
)

foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "已删除注册表项: $regPath" -ForegroundColor Yellow
    }
}

# 4. 删除服务（如果存在）
Write-Host "`n删除 SQL Server 服务..." -ForegroundColor Cyan
$services = Get-Service | Where-Object { $_.DisplayName -like "*SQL Server*" -and $_.Name -ne "MSSQLFDLauncher" }
foreach ($service in $services) {
    try {
        Stop-Service $service.Name -Force -ErrorAction SilentlyContinue
        sc.exe delete $service.Name | Out-Null
        Write-Host "已删除服务: $($service.DisplayName)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "删除服务 $($service.DisplayName) 失败: $_" -ForegroundColor Red
    }
}

# 5. 删除防火墙规则
Write-Host "`n删除 SQL Server 防火墙规则..." -ForegroundColor Cyan
$rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*SQL*" }
foreach ($rule in $rules) {
    Remove-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
    Write-Host "已删除防火墙规则: $($rule.DisplayName)" -ForegroundColor Yellow
}

Write-Host "`nSQL Server 和 SSMS 卸载完成！" -ForegroundColor Green
Write-Host "建议重启计算机以完成清理" -ForegroundColor Cyan