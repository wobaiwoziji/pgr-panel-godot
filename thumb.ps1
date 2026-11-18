# 取本地音频文件的封面缩略图（Windows 音频缩略图 = 内嵌专辑图）
# 用法: powershell -File thumb.ps1 -Path "C:\music\a.mp3"
param([string]$Path)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

function Await($op, $type) {
    if ($null -eq $op) { return $null }
    $task = $asTaskGeneric.MakeGenericMethod($type).Invoke($null, @($op))
    $task.Wait(6000) | Out-Null
    return $task.Result
}

$StorageFile = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$ThumbType = [Windows.Storage.FileProperties.StorageItemThumbnail, Windows.Storage, ContentType = WindowsRuntime]
$ModeType = [Windows.Storage.FileProperties.ThumbnailMode, Windows.Storage, ContentType = WindowsRuntime]

try {
    $Path = $Path -replace '/', '\'
    if (-not (Test-Path -LiteralPath $Path)) { 'NONE'; exit 0 }

    $file = Await ($StorageFile::GetFileFromPathAsync($Path)) $StorageFile
    if ($null -eq $file) { 'NONE'; exit 0 }

    $mode = [Enum]::Parse($ModeType, "MusicView")
    $thumb = Await ($file.GetThumbnailAsync($mode, 240)) $ThumbType
    if ($null -eq $thumb -or $thumb.Size -le 0) { 'NONE'; exit 0 }

    $net = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($thumb)
    $ms = New-Object System.IO.MemoryStream
    $net.CopyTo($ms)
    $bytes = $ms.ToArray()
    $ms.Dispose()
    $net.Dispose()
    $thumb.Dispose()

    if ($bytes.Length -le 0) { 'NONE'; exit 0 }
    [Convert]::ToBase64String($bytes)
} catch {
    'NONE'
}
