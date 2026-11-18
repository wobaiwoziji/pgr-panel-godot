# PGR Panel 托盘助手：常驻托盘图标，通过本地 TCP 给 Godot 发指令
# 由 Godot 启动，退出时随之结束
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$port = 48765
$iconPath = Join-Path $PSScriptRoot 'assets\icons\lens_core.png'

function Send-Cmd([string]$cmd) {
    try {
        $client = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $port)
        $stream = $client.GetStream()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("$cmd`n")
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
        $client.Close()
    } catch { }
}

$icon = $null
if (Test-Path $iconPath) {
    $bmp = [System.Drawing.Bitmap]::FromFile($iconPath)
    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$ni = New-Object System.Windows.Forms.NotifyIcon
if ($icon) { $ni.Icon = $icon }
$ni.Text = 'PGR Panel'
$ni.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$itemToggle = $menu.Items.Add('显示 / 收起')
$itemToggle.add_Click({ Send-Cmd 'toggle' })
$itemQuit = $menu.Items.Add('退出')
$itemQuit.add_Click({
    Send-Cmd 'quit'
    $ni.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})
$ni.ContextMenuStrip = $menu
$ni.add_MouseClick({ Send-Cmd 'toggle' })

$ctx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($ctx)
