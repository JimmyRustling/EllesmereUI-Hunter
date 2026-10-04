# Editable SVG geometry mirrored below; renders native 128px monochrome glyph art.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$bitmap = [Drawing.Bitmap]::new(512,512)
$g = [Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.ScaleTransform(512/24,512/24)
$brush = [Drawing.Brushes]::White
$blade = [Drawing.Drawing2D.GraphicsPath]::new()
$blade.AddBezier(9.2,12.4,12,7.5,16.4,3.3,21.4,2.7)
$blade.AddBezier(21.4,2.7,21,7.9,18,12.6,13,15.8)
$blade.CloseFigure(); $g.FillPath($brush,$blade)
$handle = [Drawing.Drawing2D.GraphicsPath]::new()
$handle.AddPolygon([Drawing.PointF[]]@([Drawing.PointF]::new(7.2,13.9),[Drawing.PointF]::new(10.1,16.8),[Drawing.PointF]::new(5.2,21.7),[Drawing.PointF]::new(2.6,21.7),[Drawing.PointF]::new(2.3,21.4),[Drawing.PointF]::new(2.3,18.8)))
$g.FillPath($brush,$handle)
$guard = [Drawing.Drawing2D.GraphicsPath]::new()
$guard.AddPolygon([Drawing.PointF[]]@([Drawing.PointF]::new(6.7,10.9),[Drawing.PointF]::new(13.1,17.3),[Drawing.PointF]::new(11.9,18.5),[Drawing.PointF]::new(5.5,12.1)))
$g.FillPath($brush,$guard); $g.Dispose()
$output = [Drawing.Bitmap]::new(128,128)
$scaled = [Drawing.Graphics]::FromImage($output)
$scaled.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$scaled.DrawImage($bitmap,0,0,128,128); $scaled.Dispose()
$output.Save((Join-Path $PSScriptRoot 'menu-skinning.png'),[Drawing.Imaging.ImageFormat]::Png)
$output.Dispose(); $bitmap.Dispose(); $blade.Dispose(); $handle.Dispose(); $guard.Dispose()
