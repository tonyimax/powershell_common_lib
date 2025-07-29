<#
.SYNOPSIS
   自动安装 SQL Server 和 SSMS
.DESCRIPTION
   此脚本自动下载并安装 SQL Server 和 SSMS
.NOTES
   需要以管理员权限运行
   需要互联网连接
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

# 设置变量 https://download.microsoft.com/download/95668a5c-3b79-470b-a7b9-e34d3cbfa6ae/SQL2025-SSEI-Eval.exe?culture=en-us&country=us
$tempDir = "$env:USERPROFILE\Desktop\ISO"
$sqlServerIsoUrl = "https://download.microsoft.com/download/95668a5c-3b79-470b-a7b9-e34d3cbfa6ae/SQL2025-SSEI-Eval.exe?culture=en-us&country=us" # SQL Server 2022 Developer Edition
$ssmsUrl = "https://aka.ms/ssmsfullsetup"

# 创建临时目录
if (-not (Test-Path -Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# 下载 SQL Server ISO
# Write-Host "正在下载 SQL Server ISO..." -ForegroundColor Yellow
$sqlIsoPath = "$tempDir\SQLServer2025-x64-ENU.iso"
# Invoke-WebRequest -Uri $sqlServerIsoUrl -OutFile $sqlIsoPath

# 挂载 ISO 文件
Write-Host "挂载 SQL Server ISO..." -ForegroundColor Yellow
$mountResult = Mount-DiskImage -ImagePath $sqlIsoPath -PassThru
$driveLetter = ($mountResult | Get-Volume).DriveLetter + ":"

# 静默安装 SQL Server
Write-Host "开始安装 SQL Server..." -ForegroundColor Yellow
$setupPath = "$driveLetter\setup.exe"
$installArgs = @(
    "/QS", # 静默安装
    "/ACTION=Install",
    "/FEATURES=SQL,Tools", # 安装数据库引擎和管理工具
    "/INSTANCENAME=MSSQLSERVER", # 默认实例
    "/SQLSVCACCOUNT=`"NT AUTHORITY\NETWORK SERVICE`"",
    "/SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`"",
    "/AGTSVCACCOUNT=`"NT AUTHORITY\NETWORK SERVICE`"",
    "/IACCEPTSQLSERVERLICENSETERMS",
    "/TCPENABLED=1" # 启用TCP协议
)

Start-Process -FilePath $setupPath -ArgumentList $installArgs -Wait -NoNewWindow

# 卸载 ISO 文件
Dismount-DiskImage -ImagePath $sqlIsoPath

# 下载并安装 SSMS
# Write-Host "正在下载 SSMS..." -ForegroundColor Yellow
$ssmsInstaller = "$tempDir\SSMS-Setup-CHS.exe"
# Invoke-WebRequest -Uri $ssmsUrl -OutFile $ssmsInstaller

Write-Host "开始安装 SSMS..." -ForegroundColor Yellow
$ssmsArgs = @(
    "/install",
    "/quiet",
    "/norestart"
)
Start-Process -FilePath $ssmsInstaller -ArgumentList $ssmsArgs -Wait -NoNewWindow

# 清理临时文件
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# 完成消息
Write-Host "SQL Server 和 SSMS 安装完成!" -ForegroundColor Green

# 检查服务状态
$sqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
if ($sqlService) {
    Write-Host "SQL Server 服务状态: $($sqlService.Status)"
} else {
    Write-Host "未能检测到 SQL Server 服务" -ForegroundColor Yellow
}

Write-Host "可能需要重启计算机以完成安装" -ForegroundColor Cyan