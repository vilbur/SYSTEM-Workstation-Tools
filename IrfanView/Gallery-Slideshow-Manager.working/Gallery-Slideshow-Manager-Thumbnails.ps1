param(
    [Parameter(Mandatory = $true)]
    [string]$QueuePath,

    [Parameter(Mandatory = $true)]
    [string]$DonePath,

    [string]$IrfanViewPath = ""
)

$ErrorActionPreference = "Stop"
$createdCount = 0
$skippedCount = 0
$failedCount = 0
$errorText = ""

function Set-ImageOrientation {
    param(
        [Parameter(Mandatory = $true)]
        [System.Drawing.Image]$Image
    )

    try {
        $orientationId = 0x0112

        if (-not ($Image.PropertyIdList -contains $orientationId)) {
            return
        }

        $orientation = $Image.GetPropertyItem($orientationId).Value[0]

        switch ($orientation) {
            2 { $Image.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
            3 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
            4 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipX) }
            5 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipX) }
            6 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
            7 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipX) }
            8 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
        }
    }
    catch {
    }
}

function Save-SystemDrawingThumbnail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    Add-Type -AssemblyName System.Drawing

    $sourceImage = $null
    $bitmap = $null
    $graphics = $null
    $encoderParameters = $null

    try {
        $sourceImage = [System.Drawing.Image]::FromFile($SourcePath)
        Set-ImageOrientation -Image $sourceImage

        if ($sourceImage.Width -lt 1 -or $sourceImage.Height -lt 1) {
            throw "Invalid source dimensions."
        }

        $maximumSize = 480.0
        $scale = [Math]::Min(
            $maximumSize / [double]$sourceImage.Width,
            $maximumSize / [double]$sourceImage.Height
        )

        if ($scale -gt 1.0) {
            $scale = 1.0
        }

        $targetWidth = [Math]::Max(
            1,
            [int][Math]::Round($sourceImage.Width * $scale)
        )
        $targetHeight = [Math]::Max(
            1,
            [int][Math]::Round($sourceImage.Height * $scale)
        )

        $bitmap = New-Object System.Drawing.Bitmap(
            $targetWidth,
            $targetHeight,
            [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
        )

        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::Black)
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage(
            $sourceImage,
            0,
            0,
            $targetWidth,
            $targetHeight
        )

        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
            Where-Object { $_.MimeType -eq "image/jpeg" } |
            Select-Object -First 1

        $encoderParameters = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $qualityParameter = New-Object System.Drawing.Imaging.EncoderParameter(
            [System.Drawing.Imaging.Encoder]::Quality,
            [long]84
        )
        $encoderParameters.Param[0] = $qualityParameter
        $bitmap.Save(
            $DestinationPath,
            $jpegCodec,
            $encoderParameters
        )

        return $true
    }
    finally {
        if ($encoderParameters) {
            $encoderParameters.Dispose()
        }

        if ($graphics) {
            $graphics.Dispose()
        }

        if ($bitmap) {
            $bitmap.Dispose()
        }

        if ($sourceImage) {
            $sourceImage.Dispose()
        }
    }
}

function Save-IrfanViewThumbnail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (-not $IrfanViewPath -or -not (Test-Path -LiteralPath $IrfanViewPath)) {
        return $false
    }

    & $IrfanViewPath `
        $SourcePath `
        "/silent" `
        "/resize=(480,480)" `
        "/aspectratio" `
        "/resample" `
        ("/convert=" + $DestinationPath) | Out-Null

    return (Test-Path -LiteralPath $DestinationPath)
}

try {
    if (-not (Test-Path -LiteralPath $QueuePath)) {
        throw "Thumbnail queue was not found."
    }

    $queueLines = Get-Content -LiteralPath $QueuePath -Encoding Unicode

    foreach ($line in $queueLines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = $line -split "\|", 2

        if ($parts.Count -ne 2) {
            $failedCount++
            continue
        }

        $sourcePath = $parts[0]
        $destinationPath = $parts[1]

        if (-not (Test-Path -LiteralPath $sourcePath)) {
            $failedCount++
            continue
        }

        if (Test-Path -LiteralPath $destinationPath) {
            $skippedCount++
            continue
        }

        $destinationDirectory = Split-Path -Parent $destinationPath

        if (-not (Test-Path -LiteralPath $destinationDirectory)) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force |
                Out-Null
        }

        $temporaryPath = $destinationPath + ".tmp.jpg"

        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }

        $created = $false

        try {
            $created = Save-SystemDrawingThumbnail `
                -SourcePath $sourcePath `
                -DestinationPath $temporaryPath
        }
        catch {
            $created = $false
        }

        if (-not $created) {
            try {
                $created = Save-IrfanViewThumbnail `
                    -SourcePath $sourcePath `
                    -DestinationPath $temporaryPath
            }
            catch {
                $created = $false
            }
        }

        if ($created -and (Test-Path -LiteralPath $temporaryPath)) {
            Move-Item `
                -LiteralPath $temporaryPath `
                -Destination $destinationPath `
                -Force
            $createdCount++
        }
        else {
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force
            }

            $failedCount++
        }
    }
}
catch {
    $errorText = $_.Exception.Message
}

$doneLines = @(
    "[Thumbnails]",
    "Created=$createdCount",
    "Skipped=$skippedCount",
    "Failed=$failedCount"
)

if ($errorText) {
    $sanitizedError = $errorText -replace "[\r\n=]", " "
    $doneLines += "Error=$sanitizedError"
}

Set-Content `
    -LiteralPath $DonePath `
    -Value $doneLines `
    -Encoding UTF8
