# 读取 Windows「正在播放」(SMTC)，输出 JSON 给 Electron
# 支持 Spotify / 网易云 / QQ音乐 / 浏览器 / 系统播放器等所有走 SMTC 的播放器
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

# 任意图片字节 -> 220×220 JPEG 的 data URL（顺手统一格式，避免把 jpg 当成 png）
function To-PngDataUrl($bytes) {
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $ms = New-Object System.IO.MemoryStream(, $bytes)
    $img = [System.Drawing.Image]::FromStream($ms)
    $side = 220
    $bmp = New-Object System.Drawing.Bitmap $side, $side
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $side, $side)
    $out = New-Object System.IO.MemoryStream
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $g.Dispose(); $bmp.Dispose(); $img.Dispose(); $ms.Dispose()
    return 'data:image/jpeg;base64,' + [Convert]::ToBase64String($out.ToArray())
}

function Read-Thumb($thumb) {
    if ($null -eq $thumb) { return '' }
    $stream = Await ($thumb.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
    if ($null -eq $stream) { return '' }
    try {
        $size = [int]$stream.Size
        if ($size -le 0 -or $size -ge 8000000) { return '' }
        $reader = [Windows.Storage.Streams.DataReader]::new($stream)
        Await ($reader.LoadAsync([uint32]$size)) ([uint32]) | Out-Null
        $bytes = New-Object byte[] $size
        $reader.ReadBytes($bytes)
        $reader.Dispose()
        return To-PngDataUrl $bytes
    } finally {
        $stream.Dispose()
    }
}

function Emit($obj) {
    $obj | ConvertTo-Json -Compress -Depth 4
    exit 0
}

try {
    $mgrType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
    $mgr = Await ($mgrType::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])

    # 优先挑正在播放的会话，其次才是当前会话
    $s = $null
    foreach ($it in $mgr.GetSessions()) {
        if ($it.GetPlaybackInfo().PlaybackStatus -eq 4) { $s = $it; break }
    }
    if ($null -eq $s) { $s = $mgr.GetCurrentSession() }
    if ($null -eq $s) { Emit @{ ok = $false; reason = 'no-session' } }

    $props = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
    $playing = ($s.GetPlaybackInfo().PlaybackStatus -eq 4)

    # 封面：部分播放器第一次拿不到，稍等重试两次
    $cover = ''
    for ($i = 0; $i -lt 3 -and -not $cover; $i++) {
        try { $cover = Read-Thumb $props.Thumbnail } catch { $cover = '' }
        if (-not $cover) {
            Start-Sleep -Milliseconds 150
            $props = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
        }
    }

    Emit @{
        ok      = $true
        title   = [string]$props.Title
        artist  = [string]$props.Artist
        album   = [string]$props.AlbumTitle
        playing = $playing
        cover   = $cover
    }
} catch {
    Emit @{ ok = $false; reason = "$($_.Exception.Message)" }
}
