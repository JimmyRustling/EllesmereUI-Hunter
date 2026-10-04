# The editable SVG and these paths share a 24-unit monochrome icon grid.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$bitmap = [Drawing.Bitmap]::new(512,512)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.ScaleTransform(512/24,512/24)
$pen = [Drawing.Pen]::new([Drawing.Color]::White,3)
$pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
$graphics.DrawLine($pen,10.5,10.5,21,21)
$graphics.DrawLine($pen,16,16,19,13)
$graphics.DrawLine($pen,19,19,22,16)
$graphics.DrawEllipse($pen,3,3,9,9)
$graphics.Dispose()
$output = [Drawing.Bitmap]::new(128,128)
$scaled = [Drawing.Graphics]::FromImage($output)
$scaled.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$scaled.DrawImage($bitmap,0,0,128,128)
$scaled.Dispose()
$output.Save((Join-Path $PSScriptRoot 'menu-keyring.png'),[Drawing.Imaging.ImageFormat]::Png)
$output.Dispose(); $bitmap.Dispose(); $pen.Dispose()
