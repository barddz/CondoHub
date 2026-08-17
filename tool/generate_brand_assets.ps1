Add-Type -AssemblyName System.Drawing

function New-RoundedRectanglePath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc(
        $X + $Width - $diameter,
        $Y + $Height - $diameter,
        $diameter,
        $diameter,
        0,
        90
    )
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-CondoHubIcon {
    param(
        [int]$Size,
        [string]$OutputPath
    )

    $bitmap = [System.Drawing.Bitmap]::new(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode =
        [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $scale = $Size / 512.0
    $navy = [System.Drawing.SolidBrush]::new(
        [System.Drawing.ColorTranslator]::FromHtml('#1E3A5F')
    )
    $navyLight = [System.Drawing.SolidBrush]::new(
        [System.Drawing.ColorTranslator]::FromHtml('#274C77')
    )
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $accent = [System.Drawing.SolidBrush]::new(
        [System.Drawing.ColorTranslator]::FromHtml('#60A5FA')
    )

    $graphics.FillRectangle($navy, 0, 0, $Size, $Size)
    $graphics.FillEllipse(
        $navyLight,
        260 * $scale,
        -80 * $scale,
        328 * $scale,
        328 * $scale
    )

    $leftBuilding = New-RoundedRectanglePath `
        -X (112 * $scale) -Y (184 * $scale) `
        -Width (124 * $scale) -Height (216 * $scale) -Radius (16 * $scale)
    $rightBuilding = New-RoundedRectanglePath `
        -X (276 * $scale) -Y (112 * $scale) `
        -Width (124 * $scale) -Height (288 * $scale) -Radius (16 * $scale)
    $graphics.FillPath($white, $leftBuilding)
    $graphics.FillPath($white, $rightBuilding)
    $graphics.FillRectangle(
        $white,
        220 * $scale,
        252 * $scale,
        72 * $scale,
        48 * $scale
    )

    $windowPositions = @(
        @(140, 216), @(184, 216), @(140, 260), @(184, 260),
        @(140, 304), @(184, 304), @(304, 148), @(348, 148),
        @(304, 192), @(348, 192), @(304, 236), @(348, 236),
        @(304, 280), @(348, 280)
    )

    foreach ($position in $windowPositions) {
        $window = New-RoundedRectanglePath `
            -X ($position[0] * $scale) -Y ($position[1] * $scale) `
            -Width (24 * $scale) -Height (24 * $scale) -Radius (4 * $scale)
        $graphics.FillPath($navy, $window)
        $window.Dispose()
    }

    $door = New-RoundedRectanglePath `
        -X (330 * $scale) -Y (332 * $scale) `
        -Width (32 * $scale) -Height (68 * $scale) -Radius (6 * $scale)
    $graphics.FillPath($accent, $door)

    $directory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $door.Dispose()
    $leftBuilding.Dispose()
    $rightBuilding.Dispose()
    $navy.Dispose()
    $navyLight.Dispose()
    $white.Dispose()
    $accent.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$workspace = Split-Path -Parent $PSScriptRoot
$targets = @(
    @(512, 'assets/branding/condohub_icon.png'),
    @(32, 'web/favicon.png'),
    @(192, 'web/icons/Icon-192.png'),
    @(512, 'web/icons/Icon-512.png'),
    @(192, 'web/icons/Icon-maskable-192.png'),
    @(512, 'web/icons/Icon-maskable-512.png'),
    @(48, 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png'),
    @(72, 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png'),
    @(96, 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png'),
    @(144, 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png'),
    @(192, 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'),
    @(40, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png'),
    @(60, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png'),
    @(29, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png'),
    @(58, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png'),
    @(87, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png'),
    @(80, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png'),
    @(120, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png'),
    @(120, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png'),
    @(180, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png'),
    @(20, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png'),
    @(40, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png'),
    @(76, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png'),
    @(152, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png'),
    @(167, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png'),
    @(1024, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
)

foreach ($target in $targets) {
    New-CondoHubIcon `
        -Size $target[0] `
        -OutputPath (Join-Path $workspace $target[1])
}

Write-Output "Ícones gerados: $($targets.Count)"
