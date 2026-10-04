# Editable SVG geometry mirrored below; renders native 128px monochrome glyph art.
# Paw print for the pet happiness icon: four toe pads and a main pad, tinted in game.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$bitmap = [Drawing.Bitmap]::new(512,512)
$g = [Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.ScaleTransform(512/24,512/24)
$brush = [Drawing.Brushes]::White
# Toe pads (ellipses: x, y, width, height), slightly tilted outward by position.
foreach ($toe in @(@(3.2,8.6,3.6,4.6),@(7.4,3.8,3.8,5.0),@(12.8,3.8,3.8,5.0),@(17.2,8.6,3.6,4.6))) {
    $g.FillEllipse($brush,[single]$toe[0],[single]$toe[1],[single]$toe[2],[single]$toe[3])
}
# Main pad: a rounded, slightly wider-at-the-bottom shape.
$pad = [Drawing.Drawing2D.GraphicsPath]::new()
$pad.AddBezier(12,11.6,15.6,11.6,19.2,15.4,18.6,18.4)
$pad.AddBezier(18.6,18.4,18.1,20.9,15.2,20.6,12,20.2)
$pad.AddBezier(12,20.2,8.8,20.6,5.9,20.9,5.4,18.4)
$pad.AddBezier(5.4,18.4,4.8,15.4,8.4,11.6,12,11.6)
$pad.CloseFigure(); $g.FillPath($brush,$pad); $g.Dispose()
$output = [Drawing.Bitmap]::new(128,128)
$scaled = [Drawing.Graphics]::FromImage($output)
$scaled.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$scaled.DrawImage($bitmap,0,0,128,128); $scaled.Dispose()
$output.Save((Join-Path $PSScriptRoot 'menu-paw.png'),[Drawing.Imaging.ImageFormat]::Png)
$output.Dispose(); $bitmap.Dispose(); $pad.Dispose()
