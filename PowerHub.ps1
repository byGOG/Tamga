#requires -Version 5.1

<#
    PowerHub - simple, modern bulk application installer for Windows.
    Uses the built-in Windows Package Manager (winget).
#>

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $hostExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
    Start-Process $hostExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $PSCommandPath))
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PowerHubWindowLayout {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int width, int height, bool repaint);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern int AddFontResourceEx(string fileName, uint flags, IntPtr reserved);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool RemoveFontResourceEx(string fileName, uint flags, IntPtr reserved);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint message, UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out UIntPtr result);
}
'@

function Get-PowerHubFileSha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '')
    } finally {
        $sha256.Dispose()
        $stream.Dispose()
    }
}

function Remove-PowerHubLegacyFonts {
    $legacyFonts = @(
        [pscustomobject]@{ FileName='PowerHub-Outfit.ttf'; RegistryName='Outfit (TrueType)' },
        [pscustomobject]@{ FileName='PowerHub-Poppins-Regular.ttf'; RegistryName='Poppins Regular (TrueType)' },
        [pscustomobject]@{ FileName='PowerHub-Poppins-SemiBold.ttf'; RegistryName='Poppins SemiBold (TrueType)' },
        [pscustomobject]@{ FileName='PowerHub-Orbitron.ttf'; RegistryName='Orbitron (TrueType)' },
        [pscustomobject]@{ FileName='PowerHub-FiraCode.ttf'; RegistryName='Fira Code (TrueType)' }
    )
    $fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $registryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    foreach ($font in $legacyFonts) {
        $fontPath = Join-Path $fontDirectory $font.FileName
        if (Test-Path -LiteralPath $fontPath) {
            [void][PowerHubWindowLayout]::RemoveFontResourceEx($fontPath, 0, [IntPtr]::Zero)
            Remove-Item -LiteralPath $fontPath -Force -ErrorAction SilentlyContinue
        }
        Remove-ItemProperty -Path $registryPath -Name $font.RegistryName -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'PowerHub\font.txt') -Force -ErrorAction SilentlyContinue
}

function Install-PowerHubFonts {
    $fontDefinitions = @(
        [pscustomobject]@{ Family='Inter'; FileName='PowerHub-Inter.ttf'; RegistryName='Inter (TrueType)'; Url='https://raw.githubusercontent.com/google/fonts/ec0464b978de222073645d6d3366f3fdf03376d8/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf'; Sha256='29160A80FF49DDCAB2C97711247E08B1FAB27A484A329CE8B813D820DC559031' }
    )
    $fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $registryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    [IO.Directory]::CreateDirectory($fontDirectory) | Out-Null
    if (-not (Test-Path -LiteralPath $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    $failedFamilies = [Collections.Generic.List[string]]::new()

    foreach ($font in $fontDefinitions) {
        $destination = Join-Path $fontDirectory $font.FileName
        $needsDownload = $true
        if (Test-Path -LiteralPath $destination) {
            try { $needsDownload = ((Get-PowerHubFileSha256 -Path $destination) -ne $font.Sha256) } catch {}
        }
        try {
            if ($needsDownload) {
                Write-Host '[PowerHub] Inter yazı tipi kuruluyor...' -ForegroundColor Cyan
                $temporaryFile = Join-Path $env:TEMP ("PowerHub-{0}-{1}.tmp" -f $PID, [Guid]::NewGuid().ToString('N'))
                try {
                    Invoke-WebRequest -Uri $font.Url -OutFile $temporaryFile -UseBasicParsing -ErrorAction Stop
                    $downloadHash = Get-PowerHubFileSha256 -Path $temporaryFile
                    if ($downloadHash -ne $font.Sha256) { throw "SHA-256 doğrulaması başarısız: $($font.Family)" }
                    Move-Item -LiteralPath $temporaryFile -Destination $destination -Force
                } finally {
                    if ($temporaryFile -and (Test-Path -LiteralPath $temporaryFile)) { Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue }
                }
            }
            New-ItemProperty -Path $registryPath -Name $font.RegistryName -Value $destination -PropertyType String -Force | Out-Null
            [void][PowerHubWindowLayout]::AddFontResourceEx($destination, 0, [IntPtr]::Zero)
            Write-Host ("[PowerHub] Yazı tipi hazır: {0}" -f $font.Family) -ForegroundColor Green
        } catch {
            if (-not $failedFamilies.Contains($font.Family)) { $failedFamilies.Add($font.Family) }
            Write-Host ("[PowerHub] Yazı tipi kurulamadı: {0} - {1}" -f $font.Family, $_.Exception.Message) -ForegroundColor Red
        }
    }
    $broadcastResult = [UIntPtr]::Zero
    [void][PowerHubWindowLayout]::SendMessageTimeout([IntPtr]0xFFFF, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 2000, [ref]$broadcastResult)
    return @($failedFamilies)
}

Remove-PowerHubLegacyFonts
$fontInstallFailures = @(Install-PowerHubFonts)
if ($fontInstallFailures.Count -gt 0) {
    [Windows.MessageBox]::Show("Bazı yazı tipleri kurulamadı:`n`n$($fontInstallFailures -join ', ')`n`nİnternet bağlantınızı kontrol edip PowerHub'ı yeniden açın.", 'PowerHub', 'OK', 'Warning') | Out-Null
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerHub" Width="980" Height="900" MinWidth="860" MinHeight="700"
        WindowStartupLocation="Manual" Background="{DynamicResource PageBg}"
        FontFamily="Inter" FontSize="12" TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType" TextOptions.TextHintingMode="Fixed"
        UseLayoutRounding="True" SnapsToDevicePixels="True">
    <Window.Resources>
        <SolidColorBrush x:Key="Primary" Color="#138AC2"/>
        <SolidColorBrush x:Key="Ink" Color="#F2F2F2"/>
        <SolidColorBrush x:Key="Muted" Color="#A7A7A7"/>
        <SolidColorBrush x:Key="PageBg" Color="#202020"/>
        <SolidColorBrush x:Key="CardBg" Color="#2B2B2B"/>
        <SolidColorBrush x:Key="CardBorder" Color="#414141"/>
        <SolidColorBrush x:Key="SoftBg" Color="#303030"/>
        <SolidColorBrush x:Key="SoftText" Color="#8CCFEA"/>
        <Style x:Key="SlimScrollBar" TargetType="ScrollBar">
            <Setter Property="Width" Value="10"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0"/></Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Background="#656565" CornerRadius="2" Margin="3,1"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0"/></Track.IncreaseRepeatButton>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}"
                                CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.88"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Foreground" Value="#C8C8C8"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Margin" Value="0,1"/>
            <Setter Property="Padding" Value="8,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="NavBorder" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="NavBorder" Property="Background" Value="#2A2A2A"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="NavBorder" Property="Background" Value="#303A40"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="NavBorder" Property="BorderBrush" Value="#5BCDF7"/>
                                <Setter TargetName="NavBorder" Property="BorderThickness" Value="1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="IconButton" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="Width" Value="30"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Padding" Value="0"/>
            <Setter Property="Background" Value="#303030"/>
            <Setter Property="BorderBrush" Value="#4A4A4A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Foreground" Value="#7FD5FF"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="IconSurface" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="IconSurface" Property="Background" Value="#263E49"/>
                                <Setter TargetName="IconSurface" Property="BorderBrush" Value="#168FC6"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="IconSurface" Property="Background" Value="#0D659E"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="IconSurface" Property="BorderBrush" Value="#69D2FF"/>
                                <Setter TargetName="IconSurface" Property="BorderThickness" Value="2"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="IconSurface" Property="Opacity" Value="0.42"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="AboutNavButton" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Foreground" Value="#E8F6FD"/>
            <Setter Property="BorderBrush" Value="#365565"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="9"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="AboutSurface" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}" Background="#292929">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="AboutSurface" Property="BorderBrush" Value="#258CC0"/><Setter TargetName="AboutSurface" Property="Background" Value="#244758"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="AboutSurface" Property="Background" Value="#183B4E"/></Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="AboutSurface" Property="BorderBrush" Value="#69D5FF"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="20"/>
            <Setter Property="Height" Value="20"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Width="20" Height="20">
                            <Border x:Name="CheckBorder" Background="#292929" BorderBrush="#777777"
                                    BorderThickness="1" CornerRadius="2"/>
                            <Path x:Name="CheckMark" Data="M 4 10 L 8 14 L 16 6" Stroke="White"
                                  StrokeThickness="2" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                  Visibility="Collapsed"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="CheckBorder" Property="BorderBrush" Value="{DynamicResource Primary}"/>
                                <Setter TargetName="CheckBorder" Property="Background" Value="#263F52"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="CheckBorder" Property="Background" Value="{DynamicResource Primary}"/>
                                <Setter TargetName="CheckBorder" Property="BorderBrush" Value="{DynamicResource Primary}"/>
                                <Setter TargetName="CheckMark" Property="Visibility" Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="245"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Border x:Name="Sidebar" Grid.Column="0" BorderBrush="#343434" BorderThickness="0,0,1,0" Background="#1B1B1B">
            <Grid Margin="18,20">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <StackPanel Orientation="Horizontal" Margin="8,0,0,25">
                    <Border Width="40" Height="40" CornerRadius="7" Background="#087EBD">
                        <TextBlock Text="P" Foreground="White" FontSize="21" FontWeight="Bold"
                                   HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Margin="11,0,0,0">
                        <TextBlock Text="PowerHub" Foreground="White" FontWeight="SemiBold" FontSize="18"/>
                        <TextBlock Text="Uygulama merkezi" Foreground="#9F9F9F" FontSize="11" Margin="0,2,0,0"/>
                    </StackPanel>
                </StackPanel>

                <Grid Grid.Row="1" Margin="8,0,8,8">
                    <TextBlock Text="KATEGORİLER" Foreground="#9AAEBD" FontSize="10.5" FontWeight="Bold"/>
                    <Border Height="1" Background="#404040" Margin="78,6,0,0"/>
                </Grid>
                <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Margin="0,0,0,8">
                    <ScrollViewer.Resources><Style TargetType="ScrollBar" BasedOn="{StaticResource SlimScrollBar}"/></ScrollViewer.Resources>
                    <StackPanel x:Name="CategoryPanel"/>
                </ScrollViewer>

                <Button x:Name="AboutButton" Grid.Row="3" Style="{StaticResource AboutNavButton}" Margin="0,4,0,0"
                        ToolTip="PowerHub bilgilerini ve bağlantılarını göster" AutomationProperties.Name="PowerHub hakkında">
                    <Grid Width="183">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/><ColumnDefinition Width="20"/></Grid.ColumnDefinitions>
                        <Border Width="32" Height="32" CornerRadius="5" Background="#087EBD">
                            <TextBlock Text="&#xE946;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="White" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,4,0">
                            <TextBlock Text="Hakkında" Foreground="#F1F8FC" FontSize="12.5" FontWeight="SemiBold"/>
                            <TextBlock Text="PowerHub • byGOG" Foreground="#86A9BC" FontSize="9.5" Margin="0,3,0,0"/>
                        </StackPanel>
                        <TextBlock Grid.Column="2" Text="&#xE72A;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#72CFF4" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Grid>
                </Button>

                <Border x:Name="WingetCard" Grid.Row="4" Background="#252525" BorderBrush="#414141" BorderThickness="1"
                        CornerRadius="6" Padding="10" Margin="0,8,0,0" ToolTip="winget durumunu ve kurulum motorunu gösterir">
                    <Grid>
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="38"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name="WingetIconBox" Width="30" Height="30" Background="#214B35" BorderBrush="#346A4D" BorderThickness="1" CornerRadius="5">
                            <TextBlock x:Name="WingetIcon" Text="✓" Foreground="#7EE2A8" FontSize="14" FontWeight="Bold"
                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock x:Name="WingetStatus" Grid.Column="1" Text="winget kontrol ediliyor" Foreground="White"
                                   FontSize="12.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                        <Border x:Name="WingetBadge" Grid.Column="2" Background="#204A32" BorderBrush="#346A4D" BorderThickness="1"
                                CornerRadius="4" Padding="7,4" VerticalAlignment="Center">
                            <StackPanel Orientation="Horizontal">
                                <Ellipse x:Name="WingetBadgeDot" Width="5" Height="5" Fill="#67DB95" VerticalAlignment="Center" Margin="0,0,5,0"/>
                                <TextBlock x:Name="WingetBadgeText" Text="AKTİF" Foreground="#7EE2A8" FontSize="9" FontWeight="Bold"/>
                            </StackPanel>
                        </Border>
                        <TextBlock x:Name="WingetDetail" Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="2"
                                   Text="Paket yöneticisi çevrimiçi" Foreground="#91A0AF" FontSize="10"
                                   Margin="0,5,0,0" TextWrapping="Wrap" MaxHeight="30"/>
                    </Grid>
                </Border>
            </Grid>
        </Border>

        <Grid Grid.Column="1" Margin="24,18,24,18">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Border x:Name="HeaderBanner" CornerRadius="7" Padding="18,15" Background="#282828" BorderBrush="#414141" BorderThickness="1">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="64"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="260"/>
                    </Grid.ColumnDefinitions>
                    <Border Grid.ColumnSpan="3" Height="2" VerticalAlignment="Top" Margin="-18,-15,-18,0" Background="#168FC6"/>
                    <Border Width="44" Height="44" CornerRadius="6" Background="#087EBD"
                            VerticalAlignment="Top" HorizontalAlignment="Left">
                        <Grid>
                            <Rectangle Width="21" Height="17" Fill="Transparent" Stroke="White" StrokeThickness="1.8" RadiusX="3" RadiusY="3"/>
                            <Path Data="M 15 17 L 23 17 M 19 13 L 19 21" Stroke="White" StrokeThickness="1.8"
                                  StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                        </Grid>
                    </Border>
                    <StackPanel Grid.Column="1">
                        <TextBlock Text="POWERHUB  /  WINGET" FontSize="9.5" FontWeight="Bold" Foreground="#65C9F5" Margin="0,0,0,3"/>
                        <TextBlock Text="Paket merkezi" FontSize="25" FontWeight="SemiBold" Foreground="{DynamicResource Ink}"/>
                        <TextBlock Text="Keşfet, seç ve tek akışta kur."
                                   Foreground="{DynamicResource Muted}" FontSize="14" Margin="0,5,0,0"/>
                        <StackPanel Orientation="Horizontal" Margin="0,11,0,0">
                            <Border Background="{DynamicResource SoftBg}" CornerRadius="9" Padding="9,4" Margin="0,0,7,0">
                                <TextBlock x:Name="TotalAppBadgeText" Text="0 uygulama" Foreground="{DynamicResource SoftText}" FontSize="11" FontWeight="SemiBold"/>
                            </Border>
                            <Border x:Name="SystemScanBadge" Background="#203B2C" CornerRadius="9" Padding="9,4">
                                <TextBlock x:Name="SystemScanBadgeText" Text="●  Sistem hazır" Foreground="#7EE2A8" FontSize="11" FontWeight="SemiBold"/>
                            </Border>
                            <Border Background="#343A45" CornerRadius="9" Padding="9,4" Margin="7,0,0,0">
                                <TextBlock x:Name="CategoryBadgeText" Text="0 kategori" Foreground="#C5D1DC" FontSize="11" FontWeight="SemiBold"/>
                            </Border>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Grid.Column="2" VerticalAlignment="Center">
                        <Border Background="#333333" BorderBrush="#4B4B4B"
                                BorderThickness="1" CornerRadius="4" Height="40">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="38"/><ColumnDefinition Width="*"/><ColumnDefinition Width="34"/></Grid.ColumnDefinitions>
                                <TextBlock Text="⌕" FontSize="22" Foreground="#AAB3BC" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                <TextBlock x:Name="SearchPlaceholder" Grid.Column="1" Text="Uygulama veya kaynak ara..." Foreground="#7F8A95"
                                           FontSize="13" VerticalAlignment="Center" IsHitTestVisible="False"/>
                                <TextBox x:Name="SearchBox" Grid.Column="1" BorderThickness="0" Background="Transparent"
                                         VerticalContentAlignment="Center" FontSize="14" Foreground="{DynamicResource Ink}" CaretBrush="{DynamicResource Primary}"
                                         ToolTip="Uygulama ara..." AutomationProperties.Name="Uygulama ara" Margin="0,0,8,0"/>
                                <Button x:Name="SearchClearButton" Grid.Column="2" Content="×" Width="26" Height="26" Padding="0"
                                        Background="Transparent" Foreground="#AEB9C4" FontSize="18" ToolTip="Aramayı temizle" Visibility="Collapsed"/>
                            </Grid>
                        </Border>
                        <Grid Margin="3,9,3,0">
                            <TextBlock Text="WINGET KATALOĞU" Foreground="{DynamicResource Muted}" FontSize="10" FontWeight="Bold"/>
                            <TextBlock Text="GÜVENLİ • REKLAMSIZ" HorizontalAlignment="Right" Foreground="#7EE2A8" FontSize="10" FontWeight="Bold"/>
                        </Grid>
                    </StackPanel>
                </Grid>
            </Border>

            <Grid Grid.Row="1" Margin="0,15,0,10">
                <TextBlock x:Name="SectionTitle" Text="Tüm uygulamalar" FontSize="18" FontWeight="SemiBold" Foreground="{DynamicResource Ink}" VerticalAlignment="Center"/>
                <Border HorizontalAlignment="Right" Background="#2D2D2D" BorderBrush="#454545" BorderThickness="1" CornerRadius="4" Padding="9,4">
                    <TextBlock x:Name="ResultCount" Foreground="#B8C6D1" FontSize="11" FontWeight="SemiBold"/>
                </Border>
            </Grid>

            <ListBox x:Name="AppList" Grid.Row="2" BorderThickness="0" Background="Transparent"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                <ListBox.Resources>
                    <Style TargetType="ScrollBar">
                        <Setter Property="Width" Value="9"/>
                        <Setter Property="Background" Value="Transparent"/>
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="ScrollBar">
                                    <Grid Background="#252525">
                                        <Track x:Name="PART_Track" IsDirectionReversed="True">
                                            <Track.DecreaseRepeatButton>
                                                <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0"/>
                                            </Track.DecreaseRepeatButton>
                                            <Track.Thumb>
                                                <Thumb>
                                                    <Thumb.Template>
                                                        <ControlTemplate TargetType="Thumb">
                                                            <Border Background="#656565" CornerRadius="2" Margin="2,0"/>
                                                        </ControlTemplate>
                                                    </Thumb.Template>
                                                </Thumb>
                                            </Track.Thumb>
                                            <Track.IncreaseRepeatButton>
                                                <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0"/>
                                            </Track.IncreaseRepeatButton>
                                        </Track>
                                    </Grid>
                                </ControlTemplate>
                            </Setter.Value>
                        </Setter>
                    </Style>
                </ListBox.Resources>
                <ListBox.ItemsPanel>
                    <ItemsPanelTemplate><StackPanel IsItemsHost="True"/></ItemsPanelTemplate>
                </ListBox.ItemsPanel>
                <ListBox.ItemContainerStyle>
                    <Style TargetType="ListBoxItem">
                        <Setter Property="Padding" Value="0"/><Setter Property="Margin" Value="0,0,0,6"/>
                        <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                        <Setter Property="Template">
                            <Setter.Value><ControlTemplate TargetType="ListBoxItem"><ContentPresenter/></ControlTemplate></Setter.Value>
                        </Setter>
                    </Style>
                </ListBox.ItemContainerStyle>
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <Border x:Name="CardBorder" Height="68" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1"
                                CornerRadius="5" Padding="0" ClipToBounds="True" SnapsToDevicePixels="True" Cursor="Hand">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="4"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border x:Name="AccentBar" Background="{Binding Color}"/>
                                <Grid Grid.Column="1" Margin="12,7,11,7">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="46"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="34"/><ColumnDefinition Width="32"/></Grid.ColumnDefinitions>
                                    <Border Width="38" Height="38" Background="Transparent" VerticalAlignment="Center">
                                        <Grid>
                                            <Image Source="{Binding Logo}" Width="36" Height="36" Stretch="Uniform"
                                                   HorizontalAlignment="Center" VerticalAlignment="Center" SnapsToDevicePixels="True"/>
                                            <TextBlock Text="{Binding Initial}" Opacity="{Binding InitialOpacity}" Foreground="{Binding Color}" FontWeight="Bold" FontSize="17"
                                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>
                                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,8,0">
                                        <TextBlock Text="{Binding Name}" Foreground="{DynamicResource Ink}" FontWeight="SemiBold" FontSize="14"
                                                   TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Text="{Binding Description}" Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,3,0,0"
                                                   TextTrimming="CharacterEllipsis"/>
                                    </StackPanel>
                                    <Border Grid.Column="2" Background="{Binding SourceBackground}" CornerRadius="4" Padding="7,4" Margin="8,0,7,0"
                                            VerticalAlignment="Center" ToolTip="{Binding StatusDetail}">
                                        <TextBlock Text="{Binding SourceLabel}" Foreground="{Binding SourceForeground}" FontSize="9.5" FontWeight="Bold"/>
                                    </Border>
                                    <Button x:Name="WebsiteButton" Grid.Column="3" Tag="{Binding WebsiteUrl}" Style="{StaticResource IconButton}"
                                            Visibility="{Binding WebsiteVisibility}" ToolTip="Resmî siteyi aç" AutomationProperties.Name="Resmî siteyi aç"
                                            VerticalAlignment="Center" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE71B;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="16"
                                                   Foreground="#8CDBFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Button>
                                    <CheckBox x:Name="AppCheck" Grid.Column="4" IsChecked="{Binding IsSelected, Mode=TwoWay}"
                                              Visibility="{Binding CheckVisibility}" AutomationProperties.Name="{Binding Name}"
                                              VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                </Grid>
                            </Grid>
                        </Border>
                        <DataTemplate.Triggers>
                            <DataTrigger Binding="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=ListBoxItem}}" Value="True">
                                <Setter TargetName="CardBorder" Property="Background" Value="#333333"/>
                                <Setter TargetName="CardBorder" Property="BorderBrush" Value="#595959"/>
                            </DataTrigger>
                            <DataTrigger Binding="{Binding IsChecked, ElementName=AppCheck}" Value="True">
                                <Setter TargetName="CardBorder" Property="Background" Value="#283840"/>
                                <Setter TargetName="CardBorder" Property="BorderBrush" Value="#168FC6"/>
                                <Setter TargetName="CardBorder" Property="BorderThickness" Value="1.5"/>
                            </DataTrigger>
                        </DataTemplate.Triggers>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>

            <Border Grid.Row="3" Background="#292929" BorderBrush="#454545" BorderThickness="1" CornerRadius="6" Padding="15,11" Margin="0,8,0,0">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock x:Name="SelectionText" Text="Henüz uygulama seçilmedi" Foreground="{DynamicResource Ink}" FontSize="14.5" FontWeight="SemiBold"/>
                        <TextBlock x:Name="ActivityText" Text="Kurulacak uygulamaları işaretleyin." Foreground="{DynamicResource Muted}" FontSize="12" Margin="0,4,0,0"/>
                        <ProgressBar x:Name="InstallProgress" Height="3" Margin="0,9,18,0" Minimum="0" Maximum="100"
                                     Value="0" Visibility="Collapsed" Foreground="{DynamicResource Primary}" Background="{DynamicResource SoftBg}"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <Button x:Name="SelectAllButton" Content="Görünenleri seç" Background="#333333" Foreground="#9EDBF3"
                                Margin="0,0,9,0" ToolTip="Görünen kartları seç veya seçimi kaldır (Ctrl+A)"/>
                        <Button x:Name="InstallButton" Content="Kurulumu başlat  →" Background="#087EBD" Foreground="White"
                                IsEnabled="False" ToolTip="Seçilenleri kur (Enter)"/>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>

        <Grid x:Name="AboutOverlay" Grid.ColumnSpan="2" Panel.ZIndex="100" Visibility="Collapsed">
            <Grid.Background>
                <RadialGradientBrush Center="0.5,0.44" GradientOrigin="0.5,0.44" RadiusX="0.78" RadiusY="0.78">
                    <GradientStop Color="#C8172B38" Offset="0"/><GradientStop Color="#E3080C10" Offset="0.68"/><GradientStop Color="#F205080B" Offset="1"/>
                </RadialGradientBrush>
            </Grid.Background>
            <Border x:Name="AboutBackdrop" Background="Transparent"/>
            <Border x:Name="AboutCard" Width="560" MaxHeight="740" HorizontalAlignment="Center" VerticalAlignment="Center"
                    BorderBrush="#4B6574" BorderThickness="1" CornerRadius="24" ClipToBounds="True">
                <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#182128" Offset="0"/><GradientStop Color="#12181E" Offset="1"/></LinearGradientBrush></Border.Background>
                <Border.Effect><DropShadowEffect Color="#010304" BlurRadius="52" ShadowDepth="12" Opacity="0.86"/></Border.Effect>
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="184"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0">
                        <Border.Background>
                            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                <GradientStop Color="#163B4E" Offset="0"/><GradientStop Color="#102936" Offset="0.45"/><GradientStop Color="#111821" Offset="1"/>
                            </LinearGradientBrush>
                        </Border.Background>
                        <Grid ClipToBounds="True">
                            <Border Height="2" VerticalAlignment="Top" HorizontalAlignment="Stretch"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#19BDF0" Offset="0"/><GradientStop Color="#4ED7F7" Offset="0.5"/><GradientStop Color="#745CE8" Offset="1"/></LinearGradientBrush></Border.Background></Border>
                            <Ellipse Width="260" Height="260" Stroke="#2A91BE" StrokeThickness="2" Opacity="0.23" HorizontalAlignment="Right" Margin="0,-72,30,0"/>
                            <Ellipse Width="170" Height="170" Stroke="#52D5F2" StrokeThickness="1.5" Opacity="0.24" HorizontalAlignment="Right" Margin="0,-18,82,0"/>
                            <Ellipse Width="82" Height="82" Fill="#173F52" Stroke="#48CFF2" StrokeThickness="2" HorizontalAlignment="Right" Margin="0,0,126,0">
                                <Ellipse.Effect><DropShadowEffect Color="#30BCE8" BlurRadius="30" ShadowDepth="0" Opacity="0.58"/></Ellipse.Effect>
                            </Ellipse>
                            <Path Data="M 300 145 L 390 70 L 485 118 M 330 25 L 420 105 L 535 42" Stroke="#3BBDE4" StrokeThickness="1.4" Opacity="0.32"/>
                            <Border Width="58" Height="58" CornerRadius="18" Background="#078AD5" BorderBrush="#49C9F3" BorderThickness="1" HorizontalAlignment="Left" VerticalAlignment="Bottom" Margin="28,0,0,28">
                                <Border.Effect><DropShadowEffect Color="#078AD5" BlurRadius="20" ShadowDepth="3" Opacity="0.58"/></Border.Effect>
                                <TextBlock Text="P" Foreground="White" FontSize="27" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel HorizontalAlignment="Left" VerticalAlignment="Bottom" Margin="101,0,0,31">
                                <TextBlock Text="PowerHub" Foreground="White" FontSize="25" FontWeight="Bold"/>
                                <TextBlock Text="Windows uygulama merkezi" Foreground="#8FCBE7" FontSize="11.5" Margin="0,3,0,0"/>
                            </StackPanel>
                            <Button x:Name="AboutCloseButton" HorizontalAlignment="Right" VerticalAlignment="Top" Content="&#xE711;" Width="34" Height="34"
                                    Padding="0" Margin="0,16,16,0" Background="#25323A" Foreground="#C6DCE8" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" ToolTip="Kapat (Esc)"/>
                        </Grid>
                    </Border>
                    <StackPanel Grid.Row="1" Margin="29,24,29,26">
                        <TextBlock Text="POWERHUB  /  HAKKINDA" Foreground="#62CFF5" FontSize="9.5" FontWeight="Bold"/>
                        <TextBlock Text="Uygulamaların için tek merkez." Foreground="White" FontSize="21" FontWeight="SemiBold" Margin="0,6,0,0"/>
                        <TextBlock Text="PowerHub, Windows uygulamalarını keşfetmek, resmî kaynaklara ulaşmak ve güvenli paket kurulumlarını tek merkezden yönetmek için geliştirildi."
                                   Foreground="#AEBBC5" FontSize="12.5" TextWrapping="Wrap" LineHeight="20" Margin="0,10,0,0"/>
                        <StackPanel Orientation="Horizontal" Margin="0,16,0,0">
                            <Border Background="#193344" CornerRadius="9" Padding="10,6" Margin="0,0,7,0"><TextBlock Text="✓  WinGet destekli" Foreground="#79D8FA" FontSize="10" FontWeight="SemiBold"/></Border>
                            <Border Background="#21362D" CornerRadius="9" Padding="10,6" Margin="0,0,7,0"><TextBlock Text="●  Güvenli kaynaklar" Foreground="#82DBA5" FontSize="10" FontWeight="SemiBold"/></Border>
                            <Border Background="#302D43" CornerRadius="9" Padding="10,6"><TextBlock Text="◇  Açık kaynak" Foreground="#B9AFFF" FontSize="10" FontWeight="SemiBold"/></Border>
                        </StackPanel>
                        <Border CornerRadius="13" Padding="16,14" Margin="0,17,0,0" BorderBrush="#2D424E" BorderThickness="1">
                            <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#1D2931" Offset="0"/><GradientStop Color="#192127" Offset="1"/></LinearGradientBrush></Border.Background>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="3"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Background="#26B9E8" CornerRadius="2"/>
                                <TextBlock Grid.Column="1" Foreground="#91A7B5" FontStyle="Italic" FontSize="11.5" TextWrapping="Wrap" LineHeight="18" Margin="13,0,0,0">
                                    <Hyperlink x:Name="SordumLink" NavigateUri="https://www.sordum.net/" Foreground="#69D5FF" TextDecorations="None">Sordum.net</Hyperlink><Run Text=" topluluğunun paylaşım kültürü ve kullanıcı odaklı vizyonundan ilham alınarak hazırlandı."/>
                                </TextBlock>
                            </Grid>
                        </Border>
                        <Grid Margin="0,20,0,0">
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                            <Button x:Name="AboutByGogButton" Grid.Column="0" Content="⚡  byGOG" Background="#202F38" Foreground="#DFF5FF"
                                    BorderBrush="#365365" BorderThickness="1" Padding="13,10" ToolTip="byGOG GitHub profilini aç"/>
                            <Button x:Name="AboutGitHubButton" Grid.Column="2" Content="↗  GitHub projesi" Background="#17384A" Foreground="#8EDBFF"
                                    BorderBrush="#2D6079" BorderThickness="1" Padding="13,10" ToolTip="PowerHub GitHub sayfasını aç"/>
                        </Grid>
                        <TextBlock Text="© 2026 byGOG  •  PowerShell ile açık kaynak" Foreground="#6D7E89" FontSize="9.5"
                                   HorizontalAlignment="Center" Margin="0,18,0,0"/>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{}
@('Sidebar','HeaderBanner','CategoryPanel','WingetCard','WingetIconBox','WingetIcon','WingetStatus','WingetDetail','WingetBadge','WingetBadgeDot','WingetBadgeText','TotalAppBadgeText','CategoryBadgeText','SystemScanBadge','SystemScanBadgeText','SearchBox','SearchPlaceholder','SearchClearButton','SectionTitle','ResultCount','AppList','SelectionText',
  'ActivityText','InstallProgress','SelectAllButton','InstallButton','AboutButton','AboutOverlay','AboutBackdrop','AboutCard','AboutCloseButton','AboutByGogButton','AboutGitHubButton','SordumLink') | ForEach-Object {
    $controls[$_] = $window.FindName($_)
}

function New-ColorBrush([string]$color) {
    return [Windows.Media.BrushConverter]::new().ConvertFromString($color)
}

function Resolve-WingetExecutable {
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $package = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if ($package) {
        $packagedExecutable = Join-Path $package.InstallLocation 'winget.exe'
        if (Test-Path -LiteralPath $packagedExecutable) { return $packagedExecutable }
    }
    return $null
}

function ConvertFrom-Base64Image([string]$base64) {
    $bytes = [Convert]::FromBase64String($base64)
    $stream = [IO.MemoryStream]::new($bytes)
    $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
    $bitmap.BeginInit()
    $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.StreamSource = $stream
    $bitmap.EndInit()
    $bitmap.Freeze()
    $stream.Dispose()
    return $bitmap
}

function Get-PowerHubLogoCatalog {
    $cacheDirectory = Join-Path $env:LOCALAPPDATA 'PowerHub'
    $cachePath = Join-Path $cacheDirectory 'logos.json'
    $bundledPath = Join-Path $PSScriptRoot 'logos.json'
    $developmentPath = Join-Path $PSScriptRoot 'PowerHub\logos.json'
    $isInstalledCache = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') -eq [IO.Path]::GetFullPath($cacheDirectory).TrimEnd('\')
    $catalogPath = if (-not $isInstalledCache -and (Test-Path -LiteralPath $bundledPath)) {
        $bundledPath
    } elseif (Test-Path -LiteralPath $developmentPath) {
        $developmentPath
    } else {
        $null
    }

    try {
        if (-not $catalogPath) {
            try {
                [IO.Directory]::CreateDirectory($cacheDirectory) | Out-Null
                $response = Invoke-WebRequest -UseBasicParsing -Uri 'https://bygog.github.io/PowerHub/logos.json' -TimeoutSec 15
                $json = if ($response.Content -is [byte[]]) {
                    [Text.Encoding]::UTF8.GetString([byte[]]$response.Content)
                } else {
                    [string]$response.Content
                }
                [IO.File]::WriteAllText($cachePath, $json, [Text.UTF8Encoding]::new($false))
                $catalogPath = $cachePath
            } catch {
                if (Test-Path -LiteralPath $cachePath) {
                    $catalogPath = $cachePath
                } else {
                    throw
                }
            }
        }

        $catalogObject = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $catalog = @{}
        foreach ($property in $catalogObject.PSObject.Properties) {
            $catalog[$property.Name] = [string]$property.Value
        }
        return $catalog
    } catch {
        Write-PowerHubLog -Message "Logo kataloğu yüklenemedi: $($_.Exception.Message)" -Color Yellow
        return @{}
    }
}

$sevenZipLogo = ConvertFrom-Base64Image 'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAACpSURBVFhH7Y5RCsRACEPn/pfufpRCSKJVFmYo+CDQmphxrWFY6zosGezW/bGbOSA9AMyyusCuFnB5RV1gVwu4vKIusKsFbhbRySLfOCCSy/K/k9trHxDl3IwV7KZmpUA8JMrAPDXflq3/kPngaYDLuz5nHOBriMv/8SMgo0Eu7/hu5oCchrm847uZA3Ia5vKKKrvBG6lZVmU3eEPNHcwBcsBByWC3hrP8ADYDp7tNKATcAAAAAElFTkSuQmCC'

function Set-PowerHubWindowLayout {
    $workArea = [Windows.SystemParameters]::WorkArea
    $margin = 16
    $window.Width = 980
    $window.Height = [Math]::Max($window.MinHeight, $workArea.Height - ($margin * 2))
    $window.Left = $workArea.Right - $window.Width - $margin
    $window.Top = $workArea.Top + $margin

    $terminalHandle = [IntPtr]::Zero
    $terminalProcess = Get-Process WindowsTerminal -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match 'PowerShell|Terminal' } |
        Select-Object -First 1
    if ($terminalProcess) {
        $terminalHandle = $terminalProcess.MainWindowHandle
    } else {
        $consoleHandle = [PowerHubWindowLayout]::GetConsoleWindow()
        if ($consoleHandle -ne [IntPtr]::Zero -and [PowerHubWindowLayout]::IsWindowVisible($consoleHandle)) {
            $terminalHandle = $consoleHandle
        }
    }

    if ($terminalHandle -ne [IntPtr]::Zero) {
        $screenArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $dpiScale = if ($workArea.Width -gt 0) { $screenArea.Width / $workArea.Width } else { 1 }
        $appLeftPixels = $screenArea.Left + [int](($window.Left - $workArea.Left) * $dpiScale)
        $terminalLeft = $screenArea.Left + 64
        $terminalTop = $screenArea.Top + 120
        $terminalWidth = [Math]::Max(420, $appLeftPixels - $terminalLeft - 32)
        $terminalHeight = [Math]::Min(620, [Math]::Max(420, $screenArea.Height - 80))
        [PowerHubWindowLayout]::MoveWindow($terminalHandle, $terminalLeft, $terminalTop, $terminalWidth, $terminalHeight, $true) | Out-Null
    }
}

function Write-PowerHubLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp] [PowerHub] $Message" -ForegroundColor $Color
}

$apps = [Collections.ArrayList]@(
    [pscustomobject]@{ Name='Google Chrome'; Description='Hızlı web tarayıcısı'; Id='Google.Chrome'; Category='Web Tarayıcıları'; Initial='G'; Color='#4285F4'; IsSelected=$false },
    [pscustomobject]@{ Name='Mozilla Firefox'; Description='Özgür ve gizlilik odaklı'; Id='Mozilla.Firefox'; Category='Web Tarayıcıları'; Initial='F'; Color='#FF7139'; IsSelected=$false },
    [pscustomobject]@{ Name='Brave'; Description='Reklam engelleyici tarayıcı'; Id='Brave.Brave'; Category='Web Tarayıcıları'; Initial='B'; Color='#FB542B'; IsSelected=$false },
    [pscustomobject]@{ Name='Zen Browser'; Description='Sade ve modern tarayıcı'; Id='Zen-Team.Zen-Browser'; Category='Web Tarayıcıları'; Initial='Z'; Color='#6B7CFF'; IsSelected=$false },
    [pscustomobject]@{ Name='Tor Browser'; Description='Anonimlik odaklı tarayıcı'; Id='TorProject.TorBrowser'; Category='Web Tarayıcıları'; Initial='T'; Color='#7D4698'; IsSelected=$false },
    [pscustomobject]@{ Name='Mullvad Browser'; Description='Parmak izi korumalı tarayıcı'; Id='MullvadVPN.MullvadBrowser'; Category='Web Tarayıcıları'; Initial='M'; Color='#D29422'; IsSelected=$false },

    [pscustomobject]@{ Name='Discord'; Description='Topluluk ve sesli sohbet'; Id='Discord.Discord'; Category='İletişim & Sosyal'; Initial='D'; Color='#5865F2'; IsSelected=$false },
    [pscustomobject]@{ Name='Telegram'; Description='Hızlı ve güvenli mesajlaşma'; Id='Telegram.TelegramDesktop'; Category='İletişim & Sosyal'; Initial='T'; Color='#229ED9'; IsSelected=$false },
    [pscustomobject]@{ Name='WhatsApp'; Description='Mesajlaşma ve görüntülü arama'; Id='9NKSQGP7F2NH'; InstallArguments=@('install','-e','--id','9NKSQGP7F2NH','--source','msstore'); Category='İletişim & Sosyal'; Initial='W'; Color='#25D366'; IsSelected=$false },
    [pscustomobject]@{ Name='Thunderbird'; Description='Açık kaynak e-posta istemcisi'; Id='Mozilla.Thunderbird'; Category='İletişim & Sosyal'; Initial='T'; Color='#0A84FF'; IsSelected=$false },
    [pscustomobject]@{ Name='Zoom'; Description='Video toplantıları'; Id='Zoom.Zoom'; Category='İletişim & Sosyal'; Initial='Z'; Color='#2D8CFF'; IsSelected=$false },

    [pscustomobject]@{ Name='Google Drive'; Description='Bulut depolama ve eşitleme'; Id='Google.GoogleDrive'; Category='Üretkenlik'; Initial='G'; Color='#4A8AF4'; IsSelected=$false },
    [pscustomobject]@{ Name='Dropbox'; Description='Dosya eşitleme ve paylaşım'; Id='Dropbox.Dropbox'; Category='Üretkenlik'; Initial='D'; Color='#0061FF'; IsSelected=$false },
    [pscustomobject]@{ Name='CopyQ'; Description='Gelişmiş pano yöneticisi'; Id='hluk.CopyQ'; Category='Üretkenlik'; Initial='C'; Color='#4B7D8F'; IsSelected=$false },
    [pscustomobject]@{ Name='Flow Launcher'; Description='Hızlı uygulama başlatıcı'; Id='Flow-Launcher.Flow-Launcher'; Category='Üretkenlik'; Initial='F'; Color='#5B8DEF'; IsSelected=$false },

    [pscustomobject]@{ Name='VLC'; Description='Her formatı oynatır'; Id='VideoLAN.VLC'; Category='Multimedya'; Initial='V'; Color='#F59E0B'; IsSelected=$false },
    [pscustomobject]@{ Name='OBS Studio'; Description='Kayıt ve canlı yayın'; Id='OBSProject.OBSStudio'; Category='Multimedya'; Initial='O'; Color='#4B5563'; IsSelected=$false },
    [pscustomobject]@{ Name='HandBrake'; Description='Video dönüştürme aracı'; Id='HandBrake.HandBrake'; Category='Multimedya'; Initial='H'; Color='#3FA35C'; IsSelected=$false },
    [pscustomobject]@{ Name='ImageGlass'; Description='Hafif ve modern görsel görüntüleyici'; Id='DuongDieuPhap.ImageGlass'; Category='Multimedya'; Initial='I'; Color='#D9509E'; IsSelected=$false },
    [pscustomobject]@{ Name='Spotify'; Description='Müzik ve podcast'; Id='Spotify.Spotify'; Category='Multimedya'; Initial='S'; Color='#1DB954'; IsSelected=$false },
    [pscustomobject]@{ Name='foobar2000'; Description='Özelleştirilebilir müzik oynatıcı'; Id='PeterPawlowski.foobar2000'; Category='Multimedya'; Initial='F'; Color='#566270'; IsSelected=$false },

    [pscustomobject]@{ Name='Visual Studio Code'; Description='Modern kod editörü'; Id='Microsoft.VisualStudioCode'; Category='Geliştirme'; Initial='VS'; Color='#007ACC'; IsSelected=$false },
    [pscustomobject]@{ Name='Git'; Description='Sürüm kontrol sistemi'; Id='Git.Git'; Category='Geliştirme'; Initial='G'; Color='#F05032'; IsSelected=$false },
    [pscustomobject]@{ Name='Node.js LTS'; Description='JavaScript çalışma ortamı'; Id='OpenJS.NodeJS.LTS'; Category='Geliştirme'; Initial='N'; Color='#339933'; IsSelected=$false },
    [pscustomobject]@{ Name='Python 3.13'; Description='Python geliştirme ortamı'; Id='Python.Python.3.13'; Category='Geliştirme'; Initial='Py'; Color='#3776AB'; IsSelected=$false },
    [pscustomobject]@{ Name='Docker Desktop'; Description='Konteyner geliştirme platformu'; Id='Docker.DockerDesktop'; Category='Geliştirme'; Initial='D'; Color='#2496ED'; IsSelected=$false },
    [pscustomobject]@{ Name='Postman'; Description='API geliştirme ve test aracı'; Id='Postman.Postman'; Category='Geliştirme'; Initial='P'; Color='#FF6C37'; IsSelected=$false },
    [pscustomobject]@{ Name='Notepad++'; Description='Hızlı metin ve kod editörü'; Id='Notepad++.Notepad++'; Category='Geliştirme'; Initial='N+'; Color='#73B53E'; IsSelected=$false },

    [pscustomobject]@{ Name='Claude'; Description='Anthropic yapay zeka asistanı'; Id='Anthropic.Claude'; Category='Yapay Zeka'; Initial='C'; Color='#C67C5B'; IsSelected=$false },
    [pscustomobject]@{ Name='Cursor'; Description='Yapay zeka destekli kod editörü'; Id='Anysphere.Cursor'; Category='Yapay Zeka'; Initial='C'; Color='#4A4A4A'; IsSelected=$false },
    [pscustomobject]@{ Name='Google Antigravity'; Description='Yapay zeka geliştirme aracı'; Id='Google.Antigravity'; Category='Yapay Zeka'; Initial='A'; Color='#5965D8'; IsSelected=$false },

    [pscustomobject]@{ Name='HWiNFO64'; Description='Donanım izleme ve tanılama'; Id='REALiX.HWiNFO'; Category='Donanım & Test'; Initial='H'; Color='#2979A8'; IsSelected=$false },
    [pscustomobject]@{ Name='CPU-Z'; Description='İşlemci ve sistem bilgileri'; Id='CPUID.CPU-Z'; Category='Donanım & Test'; Initial='C'; Color='#6D4BA0'; IsSelected=$false },
    [pscustomobject]@{ Name='GPU-Z'; Description='Ekran kartı bilgileri'; Id='TechPowerUp.GPU-Z'; Category='Donanım & Test'; Initial='G'; Color='#2C8D65'; IsSelected=$false },
    [pscustomobject]@{ Name='OCCT'; Description='Kararlılık ve stres testi'; Id='OCBase.OCCT.Personal'; Category='Donanım & Test'; Initial='O'; Color='#D8543D'; IsSelected=$false },
    [pscustomobject]@{ Name='FurMark 2'; Description='GPU stres ve kıyaslama testi'; Id='Geeks3D.FurMark.2'; Category='Donanım & Test'; Initial='F'; Color='#B64936'; IsSelected=$false },
    [pscustomobject]@{ Name='PassMark PerformanceTest'; Description='Bilgisayar performans testi'; Id='PassMark.PerformanceTest'; Category='Donanım & Test'; Initial='P'; Color='#35699A'; IsSelected=$false },

    [pscustomobject]@{ Name='PowerToys'; Description='Windows üretkenlik araçları'; Id='Microsoft.PowerToys'; Category='Sistem Araçları'; Initial='P'; Color='#735DD0'; IsSelected=$false },
    [pscustomobject]@{ Name='Rufus'; Description='Önyüklenebilir USB hazırlama'; Id='Rufus.Rufus'; Category='Sistem Araçları'; Initial='R'; Color='#3A7D9A'; IsSelected=$false },
    [pscustomobject]@{ Name='Ventoy'; Description='Çoklu ISO önyükleme aracı'; Id='Ventoy.Ventoy'; Category='Sistem Araçları'; Initial='V'; Color='#4A8B55'; IsSelected=$false },
    [pscustomobject]@{ Name='BleachBit'; Description='Sistem temizleme aracı'; Id='BleachBit.BleachBit'; Category='Sistem Araçları'; Initial='B'; Color='#799C3A'; IsSelected=$false },
    [pscustomobject]@{ Name='UniGetUI'; Description='Paket yöneticileri için arayüz'; Id='Devolutions.UniGetUI'; Category='Sistem Araçları'; Initial='U'; Color='#4E78A7'; IsSelected=$false },
    [pscustomobject]@{ Name='Everything'; Description='Anında dosya arama'; Id='voidtools.Everything'; Category='Dosya Yönetimi'; Initial='E'; Color='#F97316'; IsSelected=$false },

    [pscustomobject]@{ Name='Malwarebytes'; Description='Kötü amaçlı yazılım koruması'; Id='Malwarebytes.Malwarebytes'; Category='Güvenlik'; Initial='M'; Color='#1479C9'; IsSelected=$false },
    [pscustomobject]@{ Name='Bitwarden'; Description='Açık kaynak parola yöneticisi'; Id='Bitwarden.Bitwarden'; Category='Güvenlik'; Initial='B'; Color='#175DDC'; IsSelected=$false },
    [pscustomobject]@{ Name='ESET Security'; Description='Antivirüs ve internet güvenliği'; Id='ESET.Security'; Category='Güvenlik'; Initial='E'; Color='#00A6A6'; IsSelected=$false },
    [pscustomobject]@{ Name='Sandboxie Plus'; Description='Yalıtılmış uygulama ortamı'; Id='Sandboxie.Plus'; Category='Güvenlik'; Initial='S'; Color='#D5A62E'; IsSelected=$false },

    [pscustomobject]@{ Name='Proton VPN'; Description='Gizlilik odaklı VPN'; Id='Proton.ProtonVPN'; Category='Gizlilik & Ağ Ayarları'; Initial='P'; Color='#6D4AFF'; IsSelected=$false },
    [pscustomobject]@{ Name='OpenVPN Connect'; Description='Güvenli VPN istemcisi'; Id='OpenVPNTechnologies.OpenVPNConnect'; Category='Gizlilik & Ağ Ayarları'; Initial='O'; Color='#EA7E20'; IsSelected=$false },
    [pscustomobject]@{ Name='GoodbyeDPI'; Description='DPI engellerine karşı ağ aracı'; Id='ValdikSS.GoodbyeDPI'; Category='Gizlilik & Ağ Ayarları'; Initial='G'; Color='#3D7B8A'; IsSelected=$false },
    [pscustomobject]@{ Name='DNS Jumper'; Description='Hızlı DNS değiştirme aracı'; Id='sordum.DnsJumper'; Category='Gizlilik & Ağ Ayarları'; Initial='D'; Color='#3A8A7A'; IsSelected=$false },

    [pscustomobject]@{ Name='Steam'; Description='PC oyun mağazası ve platformu'; Id='Valve.Steam'; Category='Oyun & Platformlar'; Initial='S'; Color='#1B6B9B'; IsSelected=$false },
    [pscustomobject]@{ Name='Epic Games Launcher'; Description='Epic oyun mağazası'; Id='EpicGames.EpicGamesLauncher'; Category='Oyun & Platformlar'; Initial='E'; Color='#4B4B4B'; IsSelected=$false },
    [pscustomobject]@{ Name='Battle.net'; Description='Blizzard oyun platformu'; Id='Blizzard.BattleNet'; Category='Oyun & Platformlar'; Initial='B'; Color='#148EFF'; IsSelected=$false },
    [pscustomobject]@{ Name='GOG Galaxy'; Description='GOG oyun kütüphanesi'; Id='GOG.Galaxy'; Category='Oyun & Platformlar'; Initial='G'; Color='#8B4FA8'; IsSelected=$false },

    [pscustomobject]@{ Name='7-Zip'; Description='Hafif arşiv yöneticisi'; Id='7zip.7zip'; InstallArguments=@('install','-e','--id','7zip.7zip'); Category='Dosya Yönetimi'; Initial='7'; InitialOpacity=0.0; Logo=$sevenZipLogo; Color='#6B7280'; IsSelected=$false },
    [pscustomobject]@{ Name='WinRAR'; Description='Arşivleme ve sıkıştırma aracı'; Id='RARLab.WinRAR'; Category='Dosya Yönetimi'; Initial='W'; Color='#7A5B91'; IsSelected=$false },
    [pscustomobject]@{ Name='WizTree'; Description='Hızlı disk alanı analizi'; Id='AntibodySoftware.WizTree'; Category='Dosya Yönetimi'; Initial='W'; Color='#49944A'; IsSelected=$false },
    [pscustomobject]@{ Name='TeraCopy'; Description='Hızlı ve güvenilir dosya kopyalama'; Id='CodeSector.TeraCopy'; Category='Sistem Araçları'; Initial='T'; Color='#3D7FA5'; IsSelected=$false },
    [pscustomobject]@{ Name='OneCommander'; Description='Modern çift panelli dosya yöneticisi'; Id='MilosParipovic.OneCommander'; Category='Dosya Yönetimi'; Initial='1'; Color='#4B79A8'; IsSelected=$false },

    [pscustomobject]@{ Name='VirtualBox'; Description='Açık kaynak sanallaştırma'; Id='Oracle.VirtualBox'; Category='Sanallaştırma'; Initial='V'; Color='#2366A8'; IsSelected=$false },
    [pscustomobject]@{ Name='VirtualBox Extension Pack'; Description='USB ve uzak bağlantı eklentileri'; Action='Url'; Url='https://www.virtualbox.org/wiki/Downloads'; Category='Sanallaştırma'; Initial='V+'; Color='#376F9C'; IsSelected=$false },
    [pscustomobject]@{ Name='VMware Workstation Pro'; Description='Profesyonel masaüstü sanallaştırma'; Action='Url'; Url='https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion'; Category='Sanallaştırma'; Initial='VM'; Color='#E28A24'; IsSelected=$false },

    [pscustomobject]@{ Name='Office Tool Plus'; Description='Office dağıtım ve yönetim aracı'; Id='Yerong.OfficeToolPlus'; Category='Betikler & Otomasyon'; Initial='O'; Color='#D64A3A'; IsSelected=$false },
    [pscustomobject]@{ Name='CTT WinUtil'; Description='Windows bakım ve yapılandırma aracı'; Action='Url'; Url='https://github.com/ChrisTitusTech/winutil'; Category='Betikler & Otomasyon'; Initial='W'; Color='#4C8B69'; IsSelected=$false },

    [pscustomobject]@{ Name='uBlock Origin'; Description='İçerik ve takipçi engelleyici'; Action='Url'; Url='https://github.com/gorhill/uBlock'; Category='Eklentiler'; Initial='uB'; Color='#C73535'; IsSelected=$false },
    [pscustomobject]@{ Name='Dark Reader'; Description='Web siteleri için karanlık tema'; Action='Url'; Url='https://darkreader.org/'; Category='Eklentiler'; Initial='DR'; Color='#4A5365'; IsSelected=$false },
    [pscustomobject]@{ Name='SponsorBlock'; Description='YouTube sponsor bölümü atlama'; Action='Url'; Url='https://sponsor.ajay.app/'; Category='Eklentiler'; Initial='SB'; Color='#2D9B61'; IsSelected=$false },
    [pscustomobject]@{ Name='Greasy Fork'; Description='Açık kullanıcı betiği dizini'; Action='Url'; Url='https://greasyfork.org/'; Category='Eklentiler'; Initial='GF'; Color='#607D4F'; IsSelected=$false },
    [pscustomobject]@{ Name='TWP Translate Web Pages'; Description='Web sayfası çeviri eklentisi'; Action='Url'; Url='https://github.com/FilipePS/Traduzir-paginas-web'; Category='Eklentiler'; Initial='T'; Color='#3678C8'; IsSelected=$false },
    [pscustomobject]@{ Name='YouTube Auto HD'; Description='YouTube kalite seçimi eklentisi'; Action='Url'; Url='https://chromewebstore.google.com/search/YouTube%20Auto%20HD'; Category='Eklentiler'; Initial='HD'; Color='#D63A3A'; IsSelected=$false },
    [pscustomobject]@{ Name='Firefox Relay'; Description='E-posta maskeleri ve gizlilik'; Action='Url'; Url='https://relay.firefox.com/'; Category='Eklentiler'; Initial='FR'; Color='#7A4BD4'; IsSelected=$false },

    [pscustomobject]@{ Name='Gmail'; Description='Google web posta hizmeti'; Action='Url'; Url='https://mail.google.com/'; Category='İletişim & Sosyal'; Initial='G'; Color='#D94B40'; IsSelected=$false },
    [pscustomobject]@{ Name='Outlook'; Description='Microsoft web posta hizmeti'; Action='Url'; Url='https://outlook.live.com/'; Category='İletişim & Sosyal'; Initial='O'; Color='#1678C8'; IsSelected=$false },
    [pscustomobject]@{ Name='Yahoo Mail'; Description='Yahoo web posta hizmeti'; Action='Url'; Url='https://mail.yahoo.com/'; Category='İletişim & Sosyal'; Initial='Y'; Color='#6A3BC2'; IsSelected=$false },

    [pscustomobject]@{ Name='DeepL Translate'; Description='Yapay zeka destekli çeviri'; Id='DeepL.DeepL'; Category='Üretkenlik'; Initial='D'; Color='#175E85'; IsSelected=$false },

    [pscustomobject]@{ Name='K-Lite Codec Pack Full'; Description='Windows medya codec paketi'; Id='CodecGuide.K-LiteCodecPack.Full'; Category='Multimedya'; Initial='K'; Color='#4B78A5'; IsSelected=$false },
    [pscustomobject]@{ Name='Subtitle Edit'; Description='Altyazı düzenleme ve eşitleme'; Id='Nikse.SubtitleEdit'; Category='Multimedya'; Initial='SE'; Color='#397D9B'; IsSelected=$false },
    [pscustomobject]@{ Name='ShareX'; Description='Ekran görüntüsü ve paylaşım aracı'; Id='ShareX.ShareX'; Category='Multimedya'; Initial='S'; Color='#2A8CC7'; IsSelected=$false },
    [pscustomobject]@{ Name='AIMP'; Description='Hafif ve gelişmiş müzik oynatıcı'; Id='AIMP.AIMP'; Category='Multimedya'; Initial='A'; Color='#E58A2D'; IsSelected=$false },
    [pscustomobject]@{ Name='iTunes'; Description='Apple müzik ve aygıt yönetimi'; Id='Apple.iTunes'; Category='Multimedya'; Initial='i'; Color='#D94E86'; IsSelected=$false },

    [pscustomobject]@{ Name='GitHub Desktop'; Description='GitHub için masaüstü istemcisi'; Id='GitHub.GitHubDesktop'; Category='Geliştirme'; Initial='GH'; Color='#4E4A59'; IsSelected=$false },
    [pscustomobject]@{ Name='PowerShell 7'; Description='Modern çapraz platform kabuğu'; Id='Microsoft.PowerShell'; Category='Geliştirme'; Initial='PS'; Color='#3574C3'; IsSelected=$false },

    [pscustomobject]@{ Name='LLM Stats'; Description='LLM kullanım ve model istatistikleri'; Action='Url'; Url='https://llm-stats.com/'; Category='Yapay Zeka'; Initial='LS'; Color='#5265A8'; IsSelected=$false },
    [pscustomobject]@{ Name='Artificial Analysis'; Description='Yapay zeka model karşılaştırmaları'; Action='Url'; Url='https://artificialanalysis.ai/'; Category='Yapay Zeka'; Initial='AA'; Color='#5F55B5'; IsSelected=$false },
    [pscustomobject]@{ Name='Arena AI'; Description='Topluluk tabanlı yapay zeka arenası'; Action='Url'; Url='https://arena.ai/'; Category='Yapay Zeka'; Initial='A'; Color='#7861D1'; IsSelected=$false },

    [pscustomobject]@{ Name='Resource Hacker'; Description='Windows kaynak düzenleyicisi'; Id='AngusJohnson.ResourceHacker'; Category='Sistem Araçları'; Initial='RH'; Color='#47769A'; IsSelected=$false },
    [pscustomobject]@{ Name='Process Lasso'; Description='İşlem ve CPU optimizasyonu'; Id='BitSum.ProcessLasso'; Category='Sistem Araçları'; Initial='PL'; Color='#3D75A6'; IsSelected=$false },
    [pscustomobject]@{ Name='Bulk Crap Uninstaller'; Description='Toplu ve kalıntısız kaldırıcı'; Id='Klocman.BulkCrapUninstaller'; Category='Sistem Araçları'; Initial='BC'; Color='#4C8A68'; IsSelected=$false },
    [pscustomobject]@{ Name='O&O AppBuster'; Description='Windows uygulama yöneticisi'; Id='OO-Software.AppBuster'; Category='Sistem Araçları'; Initial='O'; Color='#356D9A'; IsSelected=$false },
    [pscustomobject]@{ Name='balenaEtcher'; Description='Önyüklenebilir disk yazma aracı'; Id='Balena.Etcher'; Category='Sistem Araçları'; Initial='bE'; Color='#4D72C8'; IsSelected=$false },
    [pscustomobject]@{ Name='Windows 10 Media Creation Tool'; Description='Resmî Windows 10 medya aracı'; Action='Url'; Url='https://www.microsoft.com/software-download/windows10'; Category='Sistem Araçları'; Initial='10'; Color='#1784C7'; IsSelected=$false },
    [pscustomobject]@{ Name='Windows 11 Media Creation Tool'; Description='Resmî Windows 11 medya aracı'; Action='Url'; Url='https://www.microsoft.com/software-download/windows11'; Category='Sistem Araçları'; Initial='11'; Color='#2E82C9'; IsSelected=$false },

    [pscustomobject]@{ Name='HashCheck'; Description='Dosya sağlama toplamı eklentisi'; Id='gurnec.HashCheckShellExtension'; Category='Dosya Yönetimi'; Initial='H'; Color='#6B7B8A'; IsSelected=$false },

    [pscustomobject]@{ Name='BurnInTest'; Description='Donanım kararlılık ve dayanıklılık testi'; Action='Url'; Url='https://www.passmark.com/products/burnintest/download.php'; Category='Donanım & Test'; Initial='BI'; Color='#B04B3A'; IsSelected=$false },
    [pscustomobject]@{ Name='AMD Software: Adrenalin'; Description='AMD ekran kartı sürücüleri'; Action='Url'; Url='https://www.amd.com/en/support/download/drivers.html'; Category='Donanım & Test'; Initial='A'; Color='#C63D36'; IsSelected=$false },
    [pscustomobject]@{ Name='Intel Driver & Support Assistant'; Description='Intel sürücü tarama ve güncelleme'; Id='Intel.IntelDriverAndSupportAssistant'; Category='Donanım & Test'; Initial='I'; Color='#1671B8'; IsSelected=$false },
    [pscustomobject]@{ Name='NVIDIA App'; Description='NVIDIA sürücü ve oyun ayarları'; Id='XP8CLZL93F5Z4P'; InstallArguments=@('install','-e','--id','XP8CLZL93F5Z4P','--source','msstore'); Category='Donanım & Test'; Initial='N'; Color='#6AAB35'; IsSelected=$false },
    [pscustomobject]@{ Name='DriverStore Explorer'; Description='Windows sürücü deposu yöneticisi'; Id='lostindark.DriverStoreExplorer'; Category='Donanım & Test'; Initial='DS'; Color='#53759A'; IsSelected=$false },

    [pscustomobject]@{ Name='AnyDesk'; Description='Uzak masaüstü bağlantısı'; Id='AnyDesk.AnyDesk'; Category='Ağ & Uzaktan Erişim'; Initial='A'; Color='#E14A43'; IsSelected=$false },
    [pscustomobject]@{ Name='TeamViewer'; Description='Uzaktan destek ve erişim'; Id='TeamViewer.TeamViewer'; Category='Ağ & Uzaktan Erişim'; Initial='T'; Color='#2275C9'; IsSelected=$false },
    [pscustomobject]@{ Name='LocalSend'; Description='Yerel ağda dosya paylaşımı'; Id='LocalSend.LocalSend'; Category='Ağ & Uzaktan Erişim'; Initial='L'; Color='#3E85C7'; IsSelected=$false },

    [pscustomobject]@{ Name='Sideloadly'; Description='iOS uygulama imzalama ve yükleme'; Action='Url'; Url='https://sideloadly.io/'; Category='Mobil & Araçlar'; Initial='S'; Color='#4E83B8'; IsSelected=$false },

    [pscustomobject]@{ Name='Internet Download Manager'; Description='Gelişmiş indirme yöneticisi'; Id='Tonec.InternetDownloadManager'; Category='İndirme Yöneticileri'; Initial='ID'; Color='#3A7DA2'; IsSelected=$false },
    [pscustomobject]@{ Name='JDownloader 2'; Description='Açık kaynak indirme yöneticisi'; Id='AppWork.JDownloader'; Category='İndirme Yöneticileri'; Initial='J'; Color='#D9A52E'; IsSelected=$false },
    [pscustomobject]@{ Name='qBittorrent'; Description='Açık kaynak BitTorrent istemcisi'; Id='qBittorrent.qBittorrent'; Category='İndirme Yöneticileri'; Initial='qB'; Color='#3E79B8'; IsSelected=$false },

    [pscustomobject]@{ Name='Avira Free Security'; Description='Ücretsiz antivirüs ve güvenlik'; Action='Url'; Url='https://www.avira.com/en/free-security'; Category='Güvenlik'; Initial='A'; Color='#D94A48'; IsSelected=$false },
    [pscustomobject]@{ Name='Bitdefender Antivirus Free'; Description='Ücretsiz kötü amaçlı yazılım koruması'; Action='Url'; Url='https://www.bitdefender.com/en-us/consumer/free-antivirus'; Category='Güvenlik'; Initial='B'; Color='#D52C32'; IsSelected=$false },
    [pscustomobject]@{ Name='Emsisoft Emergency Kit'; Description='Taşınabilir zararlı yazılım tarayıcısı'; Action='Url'; Url='https://www.emsisoft.com/en/home/emergency-kit/'; Category='Güvenlik'; Initial='E'; Color='#397CC1'; IsSelected=$false },

    [pscustomobject]@{ Name='Zen Privacy'; Description='Sistem genelinde reklam ve takipçi koruması'; Id='ZenPrivacy.ZenDesktop'; Category='Gizlilik & Ağ Ayarları'; Initial='Z'; Color='#287AB8'; IsSelected=$false },
    [pscustomobject]@{ Name='O&O ShutUp10++'; Description='Windows gizlilik ayarları yöneticisi'; Id='OO-Software.ShutUp10'; Category='Gizlilik & Ağ Ayarları'; Initial='O'; Color='#3C6A92'; IsSelected=$false },
    [pscustomobject]@{ Name='privacy.sexy'; Description='Açık kaynak gizlilik yapılandırmaları'; Action='Url'; Url='https://privacy.sexy/'; Category='Gizlilik & Ağ Ayarları'; Initial='p'; Color='#8A4EA0'; IsSelected=$false },
    [pscustomobject]@{ Name='GoodbyeDPI UI'; Description='GoodbyeDPI için grafik arayüz'; Action='Url'; Url='https://github.com/Storik4pro/goodbyeDPI-UI'; Category='Gizlilik & Ağ Ayarları'; Initial='GU'; Color='#447A8A'; IsSelected=$false },
    [pscustomobject]@{ Name='NextDNS'; Description='Özelleştirilebilir güvenli DNS'; Action='Url'; Url='https://nextdns.io/'; Category='Gizlilik & Ağ Ayarları'; Initial='N'; Color='#4C6FD1'; IsSelected=$false },

    [pscustomobject]@{ Name='SeriesGraph'; Description='Dizi keşif ve ilişki haritası'; Action='Url'; Url='https://seriesgraph.com/'; Category='Film & Medya'; Initial='SG'; Color='#6856A8'; IsSelected=$false },
    [pscustomobject]@{ Name='OpenSubtitles'; Description='Altyazı arama ve indirme'; Action='Url'; Url='https://www.opensubtitles.com/'; Category='Film & Medya'; Initial='OS'; Color='#4E7CA5'; IsSelected=$false },
    [pscustomobject]@{ Name='IPTVnator'; Description='Açık kaynak IPTV oynatıcısı'; Id='4gray.iptvnator'; Category='Film & Medya'; Initial='IP'; Color='#6A52C2'; IsSelected=$false },

    [pscustomobject]@{ Name='Ninite'; Description='Toplu uygulama kurulum hizmeti'; Action='Url'; Url='https://ninite.com/'; Category='Uygulama Arşivleri'; Initial='N'; Color='#3B76A0'; IsSelected=$false },
    [pscustomobject]@{ Name='Microsoft Package Picker'; Description='Microsoft Store çoklu uygulama paketi'; Action='Url'; Url='https://apps.microsoft.com/'; Category='Uygulama Arşivleri'; Initial='MP'; Color='#2778B8'; IsSelected=$false },
    [pscustomobject]@{ Name='UUP dump'; Description='Windows UUP indirme aracı'; Action='Url'; Url='https://uupdump.net/'; Category='Uygulama Arşivleri'; Initial='U'; Color='#3F78A5'; IsSelected=$false },
    [pscustomobject]@{ Name='AtlasOS'; Description='Windows performans yapılandırma projesi'; Action='Url'; Url='https://atlasos.net/'; Category='Uygulama Arşivleri'; Initial='A'; Color='#5968C5'; IsSelected=$false },
    [pscustomobject]@{ Name='Softpedia'; Description='Yazılım indirme ve inceleme dizini'; Action='Url'; Url='https://www.softpedia.com/'; Category='Uygulama Arşivleri'; Initial='S'; Color='#3E7FB0'; IsSelected=$false },
    [pscustomobject]@{ Name='TechSpot Downloads'; Description='Teknoloji ve yazılım indirme dizini'; Action='Url'; Url='https://www.techspot.com/downloads/'; Category='Uygulama Arşivleri'; Initial='TS'; Color='#D06A32'; IsSelected=$false },
    [pscustomobject]@{ Name='ReviOS'; Description='Windows yapılandırma ve optimizasyon projesi'; Action='Url'; Url='https://revi.cc/'; Category='Uygulama Arşivleri'; Initial='R'; Color='#6855B7'; IsSelected=$false },

    [pscustomobject]@{ Name='BrowserLeaks'; Description='Tarayıcı gizlilik ve sızıntı testleri'; Action='Url'; Url='https://browserleaks.com/'; Category='Test & Web Analiz'; Initial='BL'; Color='#4A7290'; IsSelected=$false },
    [pscustomobject]@{ Name='Bufferbloat Test'; Description='Gecikme ve bufferbloat testi'; Action='Url'; Url='https://www.waveform.com/tools/bufferbloat'; Category='Test & Web Analiz'; Initial='BT'; Color='#3C7D9B'; IsSelected=$false },
    [pscustomobject]@{ Name='Fast.com'; Description='Netflix internet hız testi'; Action='Url'; Url='https://fast.com/'; Category='Test & Web Analiz'; Initial='F'; Color='#C93838'; IsSelected=$false },
    [pscustomobject]@{ Name='Speedtest by Ookla'; Description='İnternet hız ve gecikme testi'; Action='Url'; Url='https://www.speedtest.net/'; Category='Test & Web Analiz'; Initial='S'; Color='#2874B5'; IsSelected=$false },
    [pscustomobject]@{ Name='Cloudflare Speed Test'; Description='Bağlantı kalitesi ve hız testi'; Action='Url'; Url='https://speed.cloudflare.com/'; Category='Test & Web Analiz'; Initial='CF'; Color='#E78B2B'; IsSelected=$false },
    [pscustomobject]@{ Name='DNS Speed Test Online'; Description='DNS çözümleyici hız karşılaştırması'; Action='Url'; Url='https://www.dnsperf.com/dns-speed-benchmark'; Category='Test & Web Analiz'; Initial='DS'; Color='#4A78A0'; IsSelected=$false },

    [pscustomobject]@{ Name='Raphi Win11Debloat'; Description='Windows 11 temizleme ve yapılandırma aracı'; Action='Url'; Url='https://github.com/Raphire/Win11Debloat'; Category='Betikler & Otomasyon'; Initial='R'; Color='#4B7B68'; IsSelected=$false },
    [pscustomobject]@{ Name='Bibata Cursor Installer'; Description='Bibata imleç temasını kurma aracı'; Action='Url'; Url='https://github.com/ful1e5/Bibata_Cursor'; Category='Betikler & Otomasyon'; Initial='B'; Color='#765B9A'; IsSelected=$false }
)

$officialWebsiteCatalog = @{
    '7-Zip' = 'https://7-zip.org/download.html'
    'AIMP' = 'https://www.aimp.ru'
    'AnyDesk' = 'https://anydesk.com/'
    'balenaEtcher' = 'https://etcher.balena.io/'
    'Battle.net' = 'https://download.battle.net/en-us/desktop'
    'Bitwarden' = 'https://bitwarden.com/'
    'BleachBit' = 'https://www.bleachbit.org/'
    'Brave' = 'https://brave.com/download'
    'Bulk Crap Uninstaller' = 'https://www.bcuninstaller.com/'
    'Claude' = 'https://claude.ai/download'
    'CopyQ' = 'https://github.com/hluk/CopyQ'
    'CPU-Z' = 'https://www.cpuid.com/softwares/cpu-z.html'
    'Cursor' = 'https://www.cursor.com/'
    'DeepL Translate' = 'https://www.deepl.com/en/app'
    'Discord' = 'https://discord.com/download'
    'DNS Jumper' = 'https://www.sordum.org/7952/dns-jumper-v2-3/'
    'Docker Desktop' = 'https://www.docker.com/products/docker-desktop'
    'DriverStore Explorer' = 'https://github.com/lostindark/DriverStoreExplorer'
    'Dropbox' = 'https://www.dropbox.com/'
    'Epic Games Launcher' = 'https://epicgames.com/download'
    'ESET Security' = 'https://www.eset.com/int/home/internet-security'
    'Everything' = 'https://www.voidtools.com/'
    'Flow Launcher' = 'https://github.com/Flow-Launcher/Flow.Launcher'
    'foobar2000' = 'https://www.foobar2000.org/'
    'FurMark 2' = 'https://geeks3d.com/furmark/downloads/'
    'Git' = 'https://gitforwindows.org/'
    'GitHub Desktop' = 'https://github.com/apps/desktop'
    'GOG Galaxy' = 'https://www.gog.com/galaxy'
    'GoodbyeDPI' = 'https://github.com/ValdikSS/GoodbyeDPI'
    'Google Antigravity' = 'https://antigravity.google/'
    'Google Chrome' = 'https://www.google.com/chrome/'
    'Google Drive' = 'https://workspace.google.com/products/drive/'
    'GPU-Z' = 'https://www.techpowerup.com/gpuz/'
    'HandBrake' = 'https://handbrake.fr/'
    'HashCheck' = 'https://github.com/gurnec/HashCheck'
    'HWiNFO64' = 'https://www.hwinfo.com/download/'
    'ImageGlass' = 'https://imageglass.org/'
    'Intel Driver & Support Assistant' = 'https://www.intel.com/content/www/us/en/support/detect.html'
    'Internet Download Manager' = 'https://www.internetdownloadmanager.com/'
    'IPTVnator' = 'https://github.com/4gray/iptvnator'
    'iTunes' = 'https://www.apple.com/itunes/'
    'JDownloader 2' = 'https://jdownloader.org'
    'K-Lite Codec Pack Full' = 'https://codecguide.com/download_k-lite_codec_pack_full.htm'
    'LocalSend' = 'https://localsend.org/'
    'Malwarebytes' = 'https://www.malwarebytes.com/mwb-download'
    'Mozilla Firefox' = 'https://www.mozilla.org/firefox/'
    'Mullvad Browser' = 'https://mullvad.net/browser'
    'Node.js LTS' = 'https://nodejs.org/'
    'Notepad++' = 'https://notepad-plus-plus.org/'
    'NVIDIA App' = 'https://www.nvidia.com/en-us/software/nvidia-app/'
    'O&O AppBuster' = 'https://www.oo-software.com/products/ooappbuster'
    'O&O ShutUp10++' = 'https://www.oo-software.com/products/ShutUp10'
    'OBS Studio' = 'https://obsproject.com/'
    'OCCT' = 'https://www.ocbase.com/download'
    'Office Tool Plus' = 'https://github.com/YerongAI/Office-Tool'
    'OneCommander' = 'https://onecommander.com/'
    'OpenVPN Connect' = 'https://openvpn.net/client/'
    'PassMark PerformanceTest' = 'https://www.passmark.com/products/performancetest/download.php'
    'Postman' = 'https://www.postman.com/downloads/'
    'PowerShell 7' = 'https://microsoft.com/PowerShell'
    'PowerToys' = 'https://github.com/microsoft/PowerToys'
    'Process Lasso' = 'https://bitsum.com/'
    'Proton VPN' = 'https://protonvpn.com/'
    'Python 3.13' = 'https://www.python.org/'
    'qBittorrent' = 'https://www.qbittorrent.org/'
    'Resource Hacker' = 'https://www.angusj.com/resourcehacker/'
    'Rufus' = 'https://rufus.ie/'
    'Sandboxie Plus' = 'https://github.com/sandboxie-plus/Sandboxie'
    'ShareX' = 'https://getsharex.com/'
    'Spotify' = 'https://www.spotify.com/download/windows/'
    'Steam' = 'https://store.steampowered.com/about/'
    'Subtitle Edit' = 'https://github.com/SubtitleEdit/subtitleedit'
    'TeamViewer' = 'https://www.teamviewer.com/en/download/windows/'
    'Telegram' = 'https://desktop.telegram.org/'
    'TeraCopy' = 'https://codesector.com/teracopy'
    'Thunderbird' = 'https://www.thunderbird.net/'
    'Tor Browser' = 'https://www.torproject.org/'
    'UniGetUI' = 'https://devolutions.net/unigetui/'
    'Ventoy' = 'https://www.ventoy.net/'
    'VirtualBox' = 'https://www.virtualbox.org/'
    'Visual Studio Code' = 'https://code.visualstudio.com'
    'VLC' = 'https://www.videolan.org/vlc/'
    'WhatsApp' = 'https://www.whatsapp.com/download'
    'WinRAR' = 'https://www.win-rar.com/'
    'WizTree' = 'https://diskanalyzer.com/'
    'Zen Browser' = 'https://zen-browser.app/'
    'Zen Privacy' = 'https://irbis.sh/zen'
    'Zoom' = 'https://zoom.us/'
}

foreach ($app in $apps) {
    if (-not $app.PSObject.Properties['Logo']) {
        $app | Add-Member -NotePropertyName Logo -NotePropertyValue $null
    }
    if (-not $app.PSObject.Properties['InitialOpacity']) {
        $app | Add-Member -NotePropertyName InitialOpacity -NotePropertyValue 1.0
    }
    $isWebResource = $app.PSObject.Properties['Action'] -and $app.Action -eq 'Url'
    $app | Add-Member -NotePropertyName IsWebResource -NotePropertyValue $isWebResource -Force
    $websiteUrl = if ($isWebResource) { $app.Url } else { $officialWebsiteCatalog[$app.Name] }
    $app | Add-Member -NotePropertyName WebsiteUrl -NotePropertyValue $websiteUrl -Force
    $app | Add-Member -NotePropertyName WebsiteVisibility -NotePropertyValue $(if ($websiteUrl) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }) -Force
    $app | Add-Member -NotePropertyName CheckVisibility -NotePropertyValue $(if ($isWebResource) { [Windows.Visibility]::Collapsed } else { [Windows.Visibility]::Visible }) -Force
    $app | Add-Member -NotePropertyName LinkVisibility -NotePropertyValue $(if ($isWebResource) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }) -Force
    if ($isWebResource) { $app.IsSelected = $false }
    $app | Add-Member -NotePropertyName InstallState -NotePropertyValue $(if ($isWebResource) { 'Web' } else { 'Pending' }) -Force
    $app | Add-Member -NotePropertyName Operation -NotePropertyValue 'Install' -Force
    $app | Add-Member -NotePropertyName StatusDetail -NotePropertyValue $(if ($isWebResource) { 'Resmî web kaynağı' } else { 'Sistem durumu taranmayı bekliyor' }) -Force
    $app | Add-Member -NotePropertyName SourceLabel -NotePropertyValue $(if ($isWebResource) { 'WEB' } else { 'BEKLİYOR' }) -Force
    $app | Add-Member -NotePropertyName SourceBackground -NotePropertyValue $(if ($isWebResource) { '#453C58' } else { '#263F52' }) -Force
    $app | Add-Member -NotePropertyName SourceForeground -NotePropertyValue $(if ($isWebResource) { '#D8C7FF' } else { '#82CEFF' }) -Force
}

$logoCatalog = Get-PowerHubLogoCatalog
foreach ($app in $apps) {
    if ($logoCatalog.ContainsKey($app.Name)) {
        try {
            $app.Logo = ConvertFrom-Base64Image $logoCatalog[$app.Name]
            $app.InitialOpacity = 0.0
        } catch {
            Write-PowerHubLog -Message "Logo okunamadı: $($app.Name)" -Color DarkYellow
        }
    }
}

$categoryDefinitions = @(
    [pscustomobject]@{ Name='Web Tarayıcıları'; Display='Web Tarayıcıları'; Glyph='E774' },
    [pscustomobject]@{ Name='Eklentiler'; Display='Eklentiler'; Glyph='E710' },
    [pscustomobject]@{ Name='İletişim & Sosyal'; Display='İletişim & Sosyal'; Glyph='E715' },
    [pscustomobject]@{ Name='Üretkenlik'; Display='Üretkenlik'; Glyph='E8F1' },
    [pscustomobject]@{ Name='Multimedya'; Display='Multimedya'; Glyph='E714' },
    [pscustomobject]@{ Name='Geliştirme'; Display='Geliştirme'; Glyph='E943' },
    [pscustomobject]@{ Name='Yapay Zeka'; Display='Yapay Zeka'; Glyph='E945' },
    [pscustomobject]@{ Name='Donanım & Test'; Display='Donanım & Test'; Glyph='E950' },
    [pscustomobject]@{ Name='Ağ & Uzaktan Erişim'; Display='Ağ & Uzaktan Erişim'; Glyph='E968' },
    [pscustomobject]@{ Name='Mobil & Araçlar'; Display='Mobil & Araçlar'; Glyph='E8EA' },
    [pscustomobject]@{ Name='Sistem Araçları'; Display='Sistem Araçları'; Glyph='E713' },
    [pscustomobject]@{ Name='Güvenlik'; Display='Güvenlik'; Glyph='E72E' },
    [pscustomobject]@{ Name='Gizlilik & Ağ Ayarları'; Display='Gizlilik & Ağ Ayarları'; Glyph='E8AC' },
    [pscustomobject]@{ Name='Oyun & Platformlar'; Display='Oyun & Platformlar'; Glyph='E7FC' },
    [pscustomobject]@{ Name='Dosya Yönetimi'; Display='Dosya Yönetimi'; Glyph='E8B7' },
    [pscustomobject]@{ Name='Sanallaştırma'; Display='Sanallaştırma'; Glyph='E7F8' },
    [pscustomobject]@{ Name='İndirme Yöneticileri'; Display='İndirme Yöneticileri'; Glyph='E896' },
    [pscustomobject]@{ Name='Film & Medya'; Display='Film & Medya'; Glyph='E8B2' },
    [pscustomobject]@{ Name='Uygulama Arşivleri'; Display='Uygulama Arşivleri'; Glyph='E8B7' },
    [pscustomobject]@{ Name='Test & Web Analiz'; Display='Test & Web Analiz'; Glyph='E9D9' },
    [pscustomobject]@{ Name='Betikler & Otomasyon'; Display='Betikler & Otomasyon'; Glyph='E756' }
)

foreach ($category in $categoryDefinitions) {
    $count = @($apps | Where-Object Category -eq $category.Name).Count
    $button = [Windows.Controls.Button]::new()
    $button.Style = $window.Resources['NavButton']
    $button.Tag = $category.Name
    $button.ToolTip = $category.Display
    $button.Margin = [Windows.Thickness]::new(0,1,0,1)
    $button.Padding = [Windows.Thickness]::new(9,7,7,7)
    [Windows.Automation.AutomationProperties]::SetName($button, "$($category.Display), $count uygulama")
    if ($category.Name -eq 'Web Tarayıcıları') {
        $button.Background = New-ColorBrush '#2D2D2D'
        $button.BorderBrush = New-ColorBrush '#168FC6'
        $button.BorderThickness = [Windows.Thickness]::new(3,0,0,0)
    }

    $grid = [Windows.Controls.Grid]::new()
    $grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $grid.ColumnDefinitions[0].Width = [Windows.GridLength]::new(30)
    $grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $grid.ColumnDefinitions[1].Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $grid.ColumnDefinitions[2].Width = [Windows.GridLength]::Auto

    $icon = [Windows.Controls.TextBlock]::new()
    $icon.Text = [string][char][Convert]::ToInt32($category.Glyph, 16)
    $icon.FontFamily = [Windows.Media.FontFamily]::new('Segoe Fluent Icons, Segoe MDL2 Assets')
    $icon.Foreground = New-ColorBrush $(if ($category.Name -eq 'Web Tarayıcıları') { '#55BCE8' } else { '#9B9B9B' })
    $icon.FontSize = 15
    $icon.HorizontalAlignment = 'Left'
    $icon.VerticalAlignment = 'Center'

    $label = [Windows.Controls.TextBlock]::new()
    $label.Text = $category.Display
    $label.Foreground = New-ColorBrush $(if ($category.Name -eq 'Web Tarayıcıları') { '#FFFFFF' } else { '#C8C8C8' })
    $label.FontSize = 11.5
    $label.FontWeight = if ($category.Name -eq 'Web Tarayıcıları') { [Windows.FontWeights]::SemiBold } else { [Windows.FontWeights]::Normal }
    $label.VerticalAlignment = 'Center'
    $label.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
    [Windows.Controls.Grid]::SetColumn($label, 1)

    $countBadge = [Windows.Controls.Border]::new()
    $countBadge.Background = New-ColorBrush $(if ($category.Name -eq 'Web Tarayıcıları') { '#25343B' } else { '#242424' })
    $countBadge.BorderBrush = New-ColorBrush $(if ($category.Name -eq 'Web Tarayıcıları') { '#366072' } else { '#444444' })
    $countBadge.BorderThickness = [Windows.Thickness]::new(1)
    $countBadge.CornerRadius = [Windows.CornerRadius]::new(7)
    $countBadge.Padding = [Windows.Thickness]::new(6,3,6,3)
    $countBadge.MinWidth = 24
    $countBadge.VerticalAlignment = 'Center'
    $countBadge.HorizontalAlignment = 'Right'
    [Windows.Controls.Grid]::SetColumn($countBadge, 2)
    $countText = [Windows.Controls.TextBlock]::new()
    $countText.Text = [string]$count
    $countText.Foreground = New-ColorBrush $(if ($category.Name -eq 'Web Tarayıcıları') { '#8DD7F4' } else { '#A0A0A0' })
    $countText.FontSize = 9
    $countText.HorizontalAlignment = 'Center'
    $countBadge.Child = $countText

    [void]$grid.Children.Add($icon)
    [void]$grid.Children.Add($label)
    [void]$grid.Children.Add($countBadge)
    $button | Add-Member -NotePropertyName IconElement -NotePropertyValue $icon
    $button | Add-Member -NotePropertyName LabelElement -NotePropertyValue $label
    $button | Add-Member -NotePropertyName CountBadge -NotePropertyValue $countBadge
    $button | Add-Member -NotePropertyName CountElement -NotePropertyValue $countText
    $button.Content = $grid
    [void]$controls.CategoryPanel.Children.Add($button)
}

$controls.TotalAppBadgeText.Text = "{0} uygulama" -f $apps.Count
$controls.CategoryBadgeText.Text = "{0} kategori" -f $categoryDefinitions.Count

$script:activeCategory = 'Web Tarayıcıları'
$script:isInstalling = $false
$script:visibleApps = @()

function Update-SelectionStatus {
    $selected = @($apps | Where-Object { $_.IsSelected -and -not $_.IsWebResource -and $_.Operation -ne 'None' })
    if ($selected.Count -eq 0) {
        $controls.SelectionText.Text = 'Henüz uygulama seçilmedi'
        $controls.ActivityText.Text = 'Kurulacak uygulamaları işaretleyin.'
    } else {
        $upgradeCount = @($selected | Where-Object Operation -eq 'Upgrade').Count
        $installCount = $selected.Count - $upgradeCount
        $controls.SelectionText.Text = if ($upgradeCount -gt 0 -and $installCount -gt 0) {
            "$installCount kurulum • $upgradeCount güncelleme"
        } elseif ($upgradeCount -gt 0) {
            "$upgradeCount uygulama güncellenecek"
        } else {
            "$installCount uygulama kurulacak"
        }
        if (-not $script:isInstalling) { $controls.ActivityText.Text = ($selected.Name -join ', ') }
    }
    $script:wingetExecutable = Resolve-WingetExecutable
    $controls.InstallButton.IsEnabled = ($selected.Count -gt 0 -and -not $script:isInstalling -and $script:wingetExecutable)
    $controls.InstallButton.Content = if (@($selected | Where-Object Operation -eq 'Upgrade').Count -gt 0) { 'İşlemi başlat  →' } else { 'Kurulumu başlat  →' }
}

function Update-AppList {
    $search = $controls.SearchBox.Text.Trim()
    $isSearching = -not [string]::IsNullOrWhiteSpace($search)
    $script:visibleApps = @($apps | Where-Object {
        $_.Category -eq $script:activeCategory -and
        (-not $isSearching -or $_.Name -like "*$search*" -or $_.Description -like "*$search*" -or $_.Category -like "*$search*")
    })
    $controls.AppList.ItemsSource = $null
    $controls.AppList.ItemsSource = $script:visibleApps
    $controls.ResultCount.Text = "{0} uygulama" -f $script:visibleApps.Count
    $controls.SectionTitle.Text = $script:activeCategory
    $hasInstallableApps = @($script:visibleApps | Where-Object { -not $_.IsWebResource -and $_.Operation -ne 'None' }).Count -gt 0
    if (-not $script:isInstalling) { $controls.SelectAllButton.IsEnabled = $hasInstallableApps }
    $controls.SelectAllButton.Content = if ($hasInstallableApps) { 'Görünenleri seç' } else { 'Karttan siteyi aç' }
    $controls.SelectAllButton.ToolTip = if ($hasInstallableApps) { 'Görünen kurulabilir uygulamaları seç veya seçimi kaldır (Ctrl+A)' } else { 'WEB kartına tıklayarak siteyi açın' }
}

function Update-SearchChrome {
    $hasSearch = -not [string]::IsNullOrWhiteSpace($controls.SearchBox.Text)
    $controls.SearchPlaceholder.Visibility = if ($hasSearch) { 'Collapsed' } else { 'Visible' }
    $controls.SearchClearButton.Visibility = if ($hasSearch) { 'Visible' } else { 'Collapsed' }
}

function Set-AppInstallState {
    param($App, [ValidateSet('Pending','NotInstalled','Installed','UpdateAvailable','Unknown')][string]$State)

    $App.InstallState = $State
    switch ($State) {
        'Pending' {
            $App.SourceLabel = 'TARANIYOR'
            $App.SourceBackground = '#263F52'
            $App.SourceForeground = '#82CEFF'
            $App.StatusDetail = 'Sistemde kurulu olup olmadığı denetleniyor'
            $App.Operation = 'None'
            $App.IsSelected = $false
            $App.CheckVisibility = [Windows.Visibility]::Collapsed
        }
        'NotInstalled' {
            $App.SourceLabel = 'KURULU DEĞİL'
            $App.SourceBackground = '#263F52'
            $App.SourceForeground = '#82CEFF'
            $App.StatusDetail = 'Bu uygulama bilgisayarda kurulu değil'
            $App.Operation = 'Install'
            $App.CheckVisibility = [Windows.Visibility]::Visible
        }
        'Installed' {
            $App.SourceLabel = 'KURULU'
            $App.SourceBackground = '#214B35'
            $App.SourceForeground = '#7EE2A8'
            $App.StatusDetail = 'Uygulama kurulu ve güncel'
            $App.Operation = 'None'
            $App.IsSelected = $false
            $App.CheckVisibility = [Windows.Visibility]::Collapsed
        }
        'UpdateAvailable' {
            $App.SourceLabel = 'GÜNCELLEME'
            $App.SourceBackground = '#574422'
            $App.SourceForeground = '#FFD58A'
            $App.StatusDetail = 'Yeni sürüm mevcut; seçerek güncelleyebilirsiniz'
            $App.Operation = 'Upgrade'
            $App.CheckVisibility = [Windows.Visibility]::Visible
        }
        'Unknown' {
            $App.SourceLabel = 'DURUM YOK'
            $App.SourceBackground = '#3A3F45'
            $App.SourceForeground = '#B9C2C9'
            $App.StatusDetail = 'Kurulum durumu belirlenemedi; uygulama yine de kurulabilir'
            $App.Operation = 'Install'
            $App.CheckVisibility = [Windows.Visibility]::Visible
        }
    }
}

function Test-WingetOutputContainsId {
    param([AllowEmptyString()][string]$Output, [string]$Id)
    if ([string]::IsNullOrWhiteSpace($Output) -or [string]::IsNullOrWhiteSpace($Id)) { return $false }
    $pattern = '(?im)(?<![A-Za-z0-9._-])' + [Regex]::Escape($Id) + '(?=\s|$)'
    return [Regex]::IsMatch($Output, $pattern)
}

function Update-SystemScanSummary {
    $installedCount = @($apps | Where-Object { $_.InstallState -in @('Installed','UpdateAvailable') }).Count
    $updateCount = @($apps | Where-Object InstallState -eq 'UpdateAvailable').Count
    $controls.SystemScanBadge.Background = New-ColorBrush $(if ($updateCount -gt 0) { '#574422' } else { '#203B2C' })
    $controls.SystemScanBadgeText.Foreground = New-ColorBrush $(if ($updateCount -gt 0) { '#FFD58A' } else { '#7EE2A8' })
    $controls.SystemScanBadgeText.Text = if ($updateCount -gt 0) { "●  $installedCount kurulu • $updateCount yeni" } else { "●  $installedCount kurulu" }
    $controls.SystemScanBadge.ToolTip = if ($updateCount -gt 0) { "$updateCount uygulama için güncelleme var" } else { 'Taranan uygulamalar güncel' }
}

$script:systemScanProcess = $null
$script:systemScanResultFile = $null
$script:systemScanTimer = [Windows.Threading.DispatcherTimer]::new()
$script:systemScanTimer.Interval = [TimeSpan]::FromMilliseconds(450)

function Complete-SystemScan {
    param($ScanResult)

    if (-not $ScanResult -or [int]$ScanResult.InstalledExitCode -ne 0) {
        throw 'WinGet kurulu uygulama listesini döndüremedi.'
    }

    $installedOutput = [string]$ScanResult.InstalledOutput
    $upgradeOutput = [string]$ScanResult.UpgradeOutput
    foreach ($app in @($apps | Where-Object { -not $_.IsWebResource })) {
        if (Test-WingetOutputContainsId -Output $upgradeOutput -Id $app.Id) {
            Set-AppInstallState -App $app -State UpdateAvailable
        } elseif (Test-WingetOutputContainsId -Output $installedOutput -Id $app.Id) {
            Set-AppInstallState -App $app -State Installed
        } else {
            Set-AppInstallState -App $app -State NotInstalled
        }
    }

    Update-AppList
    Update-SelectionStatus
    Update-SystemScanSummary
    $installedCount = @($apps | Where-Object { $_.InstallState -in @('Installed','UpdateAvailable') }).Count
    $updateCount = @($apps | Where-Object InstallState -eq 'UpdateAvailable').Count
    $controls.ActivityText.Text = "Sistem tarandı: $installedCount kurulu, $updateCount güncelleme."
    Write-PowerHubLog -Message "Akıllı tarama tamamlandı: $installedCount kurulu, $updateCount güncelleme." -Color Green
}

$script:systemScanTimer.Add_Tick({
    if (-not $script:systemScanProcess) { return }
    $script:systemScanProcess.Refresh()
    if (-not $script:systemScanProcess.HasExited) { return }

    $script:systemScanTimer.Stop()
    $script:systemScanProcess.WaitForExit()
    $script:systemScanProcess.Dispose()
    $script:systemScanProcess = $null
    try {
        if (-not $script:systemScanResultFile -or -not (Test-Path -LiteralPath $script:systemScanResultFile)) {
            throw 'Tarama sonucu oluşturulamadı.'
        }
        $scanResult = Get-Content -LiteralPath $script:systemScanResultFile -Raw -Encoding UTF8 | ConvertFrom-Json
        Complete-SystemScan -ScanResult $scanResult
    } catch {
        foreach ($app in @($apps | Where-Object { -not $_.IsWebResource })) { Set-AppInstallState -App $app -State Unknown }
        Update-AppList
        Update-SelectionStatus
        $controls.SystemScanBadge.Background = New-ColorBrush '#543136'
        $controls.SystemScanBadgeText.Foreground = New-ColorBrush '#FFAAAA'
        $controls.SystemScanBadgeText.Text = '●  Tarama başarısız'
        $controls.SystemScanBadge.ToolTip = $_.Exception.Message
        $controls.ActivityText.Text = 'Sistem taraması tamamlanamadı; uygulamalar yine de kurulabilir.'
        Write-PowerHubLog -Message "Akıllı tarama hatası: $($_.Exception.Message)" -Color Red
    } finally {
        if ($script:systemScanResultFile) { Remove-Item -LiteralPath $script:systemScanResultFile -Force -ErrorAction SilentlyContinue }
        $script:systemScanResultFile = $null
    }
})

function Start-SystemScan {
    if ($script:systemScanProcess -or $script:isInstalling) { return }
    $winget = Resolve-WingetExecutable
    if (-not $winget) { return }

    foreach ($app in @($apps | Where-Object { -not $_.IsWebResource })) { Set-AppInstallState -App $app -State Pending }
    Update-AppList
    Update-SelectionStatus
    $controls.SelectAllButton.IsEnabled = $false
    $controls.SystemScanBadge.Background = New-ColorBrush '#263F52'
    $controls.SystemScanBadgeText.Foreground = New-ColorBrush '#82CEFF'
    $controls.SystemScanBadgeText.Text = '◌  Sistem taranıyor'
    $controls.SystemScanBadge.ToolTip = 'Kurulu uygulamalar ve güncellemeler denetleniyor'
    $controls.ActivityText.Text = 'Kurulu uygulamalar ve güncellemeler taranıyor...'
    Write-PowerHubLog -Message 'Akıllı sistem taraması başlatıldı.' -Color Cyan

    $script:systemScanResultFile = Join-Path $env:TEMP ("PowerHub-scan-{0}.json" -f [Guid]::NewGuid().ToString('N'))
    $payloadJson = @{ Winget=$winget; ResultFile=$script:systemScanResultFile } | ConvertTo-Json -Compress
    $payloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payloadJson))
    $scanWorker = @'
$ErrorActionPreference = 'Stop'
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$payload = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__PAYLOAD__')) | ConvertFrom-Json
$result = [ordered]@{ InstalledExitCode=1; UpgradeExitCode=1; InstalledOutput=''; UpgradeOutput='' }
try {
    $result.InstalledOutput = (& $payload.Winget list --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
    $result.InstalledExitCode = [int]$LASTEXITCODE
    $result.UpgradeOutput = (& $payload.Winget list --upgrade-available --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
    $result.UpgradeExitCode = [int]$LASTEXITCODE
} catch {
    $result.InstalledOutput = $_.Exception.Message
} finally {
    [IO.File]::WriteAllText($payload.ResultFile, ($result | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
}
'@.Replace('__PAYLOAD__', $payloadBase64)
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scanWorker))
    try {
        $script:systemScanProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
            '-NoProfile','-ExecutionPolicy','Bypass','-OutputFormat','Text','-EncodedCommand',$encodedCommand
        ) -PassThru -NoNewWindow
        $script:systemScanTimer.Start()
    } catch {
        $script:systemScanProcess = $null
        if ($script:systemScanResultFile) { Remove-Item -LiteralPath $script:systemScanResultFile -Force -ErrorAction SilentlyContinue }
        $script:systemScanResultFile = $null
        foreach ($app in @($apps | Where-Object { -not $_.IsWebResource })) { Set-AppInstallState -App $app -State Unknown }
        Update-AppList
        Write-PowerHubLog -Message "Akıllı tarama başlatılamadı: $($_.Exception.Message)" -Color Red
    }
}

function Find-VisualChild {
    param(
        [Windows.DependencyObject]$Parent,
        [Type]$ChildType
    )

    if (-not $Parent) { return $null }
    for ($index = 0; $index -lt [Windows.Media.VisualTreeHelper]::GetChildrenCount($Parent); $index++) {
        $child = [Windows.Media.VisualTreeHelper]::GetChild($Parent, $index)
        if ($ChildType.IsInstanceOfType($child)) { return $child }
        $match = Find-VisualChild -Parent $child -ChildType $ChildType
        if ($match) { return $match }
    }
    return $null
}

function Set-ActiveCategory {
    param([Parameter(Mandatory)][string]$CategoryName)

    $script:activeCategory = $CategoryName
    $targetButton = $null
    foreach ($nav in @($controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] })) {
        $nav.Background = [Windows.Media.Brushes]::Transparent
        $nav.BorderBrush = [Windows.Media.Brushes]::Transparent
        $nav.BorderThickness = [Windows.Thickness]::new(0)
        $nav.IconElement.Foreground = New-ColorBrush '#9B9B9B'
        $nav.LabelElement.Foreground = New-ColorBrush '#C8C8C8'
        $nav.LabelElement.FontWeight = [Windows.FontWeights]::Normal
        $nav.CountBadge.Background = New-ColorBrush '#242424'
        $nav.CountBadge.BorderBrush = New-ColorBrush '#444444'
        $nav.CountElement.Foreground = New-ColorBrush '#A0A0A0'
        if ([string]$nav.Tag -eq $CategoryName) { $targetButton = $nav }
    }
    if ($targetButton) {
        $targetButton.Background = New-ColorBrush '#2D2D2D'
        $targetButton.BorderBrush = New-ColorBrush '#168FC6'
        $targetButton.BorderThickness = [Windows.Thickness]::new(3, 0, 0, 0)
        $targetButton.IconElement.Foreground = New-ColorBrush '#55BCE8'
        $targetButton.LabelElement.Foreground = New-ColorBrush '#FFFFFF'
        $targetButton.LabelElement.FontWeight = [Windows.FontWeights]::SemiBold
        $targetButton.CountBadge.Background = New-ColorBrush '#25343B'
        $targetButton.CountBadge.BorderBrush = New-ColorBrush '#366072'
        $targetButton.CountElement.Foreground = New-ColorBrush '#8DD7F4'
        $targetButton.BringIntoView()
    }
}

function Find-BestSearchCategory {
    param([string]$Query)
    if ([string]::IsNullOrWhiteSpace($Query)) { return $null }

    $ranked = foreach ($app in $apps) {
        $score = if ($app.Name -eq $Query) { 1000 }
            elseif ($app.Name -like "$Query*") { 800 }
            elseif ($app.Name -like "*$Query*") { 600 }
            elseif ($app.Category -eq $Query) { 500 }
            elseif ($app.Category -like "*$Query*") { 400 }
            elseif ($app.Description -like "*$Query*") { 200 }
            else { 0 }
        if ($score -gt 0) { [pscustomobject]@{ App=$app; Score=$score } }
    }
    $best = $ranked | Sort-Object @{ Expression='Score'; Descending=$true }, @{ Expression={ $_.App.Name.Length }; Ascending=$true } | Select-Object -First 1
    if ($best) { return [string]$best.App.Category }
    return $null
}

$controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] } | ForEach-Object {
    $button = $_
    $button.Add_Click({
        param($sender, $eventArgs)
        Set-ActiveCategory -CategoryName ([string]$sender.Tag)
        Update-AppList
    })
}

$controls.SearchBox.Add_TextChanged({
    Update-SearchChrome
    $searchCategory = Find-BestSearchCategory -Query $controls.SearchBox.Text.Trim()
    if ($searchCategory) { Set-ActiveCategory -CategoryName $searchCategory }
    Update-AppList
})
$controls.SearchClearButton.Add_Click({
    $controls.SearchBox.Clear()
    $controls.SearchBox.Focus() | Out-Null
})
function Set-PowerHubAboutVisibility([bool]$Visible) {
    $controls.AboutOverlay.Visibility = if ($Visible) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    if ($Visible) { $controls.AboutCloseButton.Focus() | Out-Null }
}
$controls.AboutButton.Add_Click({ Set-PowerHubAboutVisibility $true })
$controls.AboutCloseButton.Add_Click({ Set-PowerHubAboutVisibility $false })
$controls.AboutBackdrop.Add_MouseLeftButtonUp({ Set-PowerHubAboutVisibility $false })
$controls.AboutByGogButton.Add_Click({
    try { Start-Process -FilePath 'https://github.com/byGOG' } catch { Write-PowerHubLog -Message "byGOG profili açılamadı: $($_.Exception.Message)" -Color Red }
})
$controls.AboutGitHubButton.Add_Click({
    try { Start-Process -FilePath 'https://github.com/byGOG/PowerHub' } catch { Write-PowerHubLog -Message "GitHub projesi açılamadı: $($_.Exception.Message)" -Color Red }
})
$controls.SordumLink.Add_RequestNavigate({
    param($sender, $eventArgs)
    try { Start-Process -FilePath $eventArgs.Uri.AbsoluteUri } catch { Write-PowerHubLog -Message "Sordum.net açılamadı: $($_.Exception.Message)" -Color Red }
    $eventArgs.Handled = $true
})
$controls.AppList.AddHandler([Windows.Controls.CheckBox]::CheckedEvent, [Windows.RoutedEventHandler]{ Update-SelectionStatus })
$controls.AppList.AddHandler([Windows.Controls.CheckBox]::UncheckedEvent, [Windows.RoutedEventHandler]{ Update-SelectionStatus })
function Open-PowerHubWebsite {
    param($Item, [string]$Url, [switch]$WebResource)
    if ([string]::IsNullOrWhiteSpace($Url)) { return }
    $now = [DateTime]::UtcNow
    if ($script:lastWebsiteUrl -eq $Url -and ($now - $script:lastWebsiteOpenAt).TotalMilliseconds -lt 750) { return }
    $script:lastWebsiteUrl = $Url
    $script:lastWebsiteOpenAt = $now
    try {
        Start-Process -FilePath $Url
        $label = if ($WebResource) { 'Site açıldı' } else { 'Resmî site açıldı' }
        $controls.ActivityText.Text = "$label`: $($Item.Name)"
        Write-PowerHubLog -Message "$label`: $($Item.Name) — $Url" -Color Cyan
    } catch {
        $controls.ActivityText.Text = "Site açılamadı: $($Item.Name)"
        Write-PowerHubLog -Message "Site açılamadı ($($Item.Name)): $($_.Exception.Message)" -Color Red
    }
}

$script:lastWebsiteUrl = $null
$script:lastWebsiteOpenAt = [DateTime]::MinValue
$websiteClickHandler = [Windows.RoutedEventHandler]{
    param($sender, $eventArgs)
    $button = $eventArgs.Source -as [Windows.Controls.Button]
    if (-not $button) {
        $node = $eventArgs.OriginalSource
        while ($node -and -not ($node -is [Windows.Controls.Button])) {
            try { $node = [Windows.Media.VisualTreeHelper]::GetParent($node) } catch { $node = $null }
        }
        $button = $node -as [Windows.Controls.Button]
    }
    if (-not $button -or [string]::IsNullOrWhiteSpace([string]$button.Tag)) { return }
    $container = [Windows.Controls.ItemsControl]::ContainerFromElement($controls.AppList, $button)
    if (-not $container) { return }
    $item = $container.DataContext
    Open-PowerHubWebsite -Item $item -Url ([string]$button.Tag) -WebResource:$item.IsWebResource
    $eventArgs.Handled = $true
}
$controls.AppList.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, $websiteClickHandler, $true)

$controls.AppList.Add_PreviewMouseLeftButtonUp({
    param($sender, $eventArgs)

    $source = $eventArgs.OriginalSource
    $container = [Windows.Controls.ItemsControl]::ContainerFromElement($controls.AppList, $source)
    if (-not $container) { return }
    $item = $container.DataContext

    $node = $source
    while ($node) {
        if ($node -is [Windows.Controls.Button]) {
            Open-PowerHubWebsite -Item $item -Url ([string]$node.Tag) -WebResource:$item.IsWebResource
            $eventArgs.Handled = $true
            return
        }
        if ($node -is [Windows.Controls.CheckBox]) { return }
        try { $node = [Windows.Media.VisualTreeHelper]::GetParent($node) } catch { $node = $null }
    }

    if ($item.IsWebResource) {
        Open-PowerHubWebsite -Item $item -Url $item.Url -WebResource
        $eventArgs.Handled = $true
        return
    }

    $checkBox = Find-VisualChild -Parent $container -ChildType ([Windows.Controls.CheckBox])
    if ($checkBox -and $item.Operation -ne 'None' -and $checkBox.Visibility -eq [Windows.Visibility]::Visible) {
        $checkBox.IsChecked = -not [bool]$checkBox.IsChecked
        $eventArgs.Handled = $true
    }
})

$window.Add_PreviewKeyDown({
    param($sender, $eventArgs)

    if ($eventArgs.Key -eq [Windows.Input.Key]::Escape -and $controls.AboutOverlay.Visibility -eq [Windows.Visibility]::Visible) {
        Set-PowerHubAboutVisibility $false
        $eventArgs.Handled = $true
        return
    }
    $controlDown = ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0
    if ($controlDown -and $eventArgs.Key -eq [Windows.Input.Key]::F) {
        $controls.SearchBox.Focus() | Out-Null
        $controls.SearchBox.SelectAll()
        $eventArgs.Handled = $true
        return
    }
    if ($eventArgs.Key -eq [Windows.Input.Key]::Escape -and -not [string]::IsNullOrWhiteSpace($controls.SearchBox.Text)) {
        $controls.SearchBox.Clear()
        $eventArgs.Handled = $true
        return
    }
    if ($controlDown -and $eventArgs.Key -eq [Windows.Input.Key]::A -and -not $controls.SearchBox.IsKeyboardFocusWithin) {
        foreach ($app in @($script:visibleApps | Where-Object { -not $_.IsWebResource -and $_.Operation -ne 'None' })) { $app.IsSelected = $true }
        Update-AppList
        Update-SelectionStatus
        $eventArgs.Handled = $true
        return
    }
    if ($eventArgs.Key -eq [Windows.Input.Key]::Enter -and -not $controls.SearchBox.IsKeyboardFocusWithin -and $controls.InstallButton.IsEnabled) {
        $controls.InstallButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        $eventArgs.Handled = $true
    }
})

$controls.SelectAllButton.Add_Click({
    $installableApps = @($script:visibleApps | Where-Object { -not $_.IsWebResource -and $_.Operation -ne 'None' })
    $allSelected = $installableApps.Count -gt 0 -and @($installableApps | Where-Object { -not $_.IsSelected }).Count -eq 0
    foreach ($app in $installableApps) { $app.IsSelected = -not $allSelected }
    Update-AppList
    Update-SelectionStatus
})

$script:installQueue = @()
$script:installIndex = 0
$script:installResults = [Collections.ArrayList]::new()
$script:installProcess = $null
$script:installTimer = [Windows.Threading.DispatcherTimer]::new()
$script:installTimer.Interval = [TimeSpan]::FromMilliseconds(400)

function Complete-InstallQueue {
    $script:installTimer.Stop()
    $script:isInstalling = $false
    $controls.SelectAllButton.IsEnabled = @($script:visibleApps | Where-Object { -not $_.IsWebResource -and $_.Operation -ne 'None' }).Count -gt 0
    $controls.InstallButton.IsEnabled = $true
    $controls.InstallProgress.Value = 100

    $failed = @($script:installResults | Where-Object { -not $_.Success })
    $manualCount = @($script:installResults | Where-Object Manual).Count
    $successCount = @($script:installResults | Where-Object { $_.Success -and -not $_.Manual }).Count
    $summary = if ($manualCount -gt 0) { "$successCount kuruldu, $manualCount indirme sayfası açıldı" } else { "$successCount başarılı" }
    if ($failed.Count -eq 0) {
        Write-PowerHubLog -Message "İşlem tamamlandı: $summary." -Color Green
        $controls.ActivityText.Text = "$summary."
    } else {
        Write-PowerHubLog -Message "İşlem tamamlandı: $summary, $($failed.Count) başarısız." -Color Yellow
        $controls.ActivityText.Text = "$summary, $($failed.Count) başarısız."
        $failedText = ($failed | ForEach-Object { "• $($_.Name) (kod: $($_.Code))" }) -join "`n"
        [Windows.MessageBox]::Show($window, "Bazı kurulumlar tamamlanamadı:`n`n$failedText", 'PowerHub', 'OK', 'Warning') | Out-Null
    }
    Start-SystemScan
}

function Start-NextInstall {
    if ($script:installIndex -ge $script:installQueue.Count) {
        Complete-InstallQueue
        return
    }

    $item = $script:installQueue[$script:installIndex]
    $controls.InstallProgress.Value = [int](($script:installIndex / $script:installQueue.Count) * 100)

    if ($item.Action -eq 'Url') {
        try {
            $controls.ActivityText.Text = "İndirme sayfası açılıyor: $($item.Name)"
            Write-PowerHubLog -Message "Resmî indirme sayfası açılıyor: $($item.Name)" -Color Cyan
            Start-Process -FilePath $item.Url
            [void]$script:installResults.Add([pscustomobject]@{ Name=$item.Name; Success=$true; Manual=$true; Code=0 })
        } catch {
            Write-PowerHubLog -Message "Sayfa açılamadı ($($item.Name)): $($_.Exception.Message)" -Color Red
            [void]$script:installResults.Add([pscustomobject]@{ Name=$item.Name; Success=$false; Manual=$true; Code=-1 })
        }
        $script:installIndex++
        Start-NextInstall
        return
    }

    $controls.ActivityText.Text = "Kuruluyor: $($item.Name)"
    $installArguments = if ($item.Operation -eq 'Upgrade') {
        @('upgrade','--id',$item.Id,'--exact','--source',$item.PackageSource)
    } elseif ($item.InstallArguments) {
        @($item.InstallArguments)
    } else {
        @('install','--id',$item.Id,'--exact')
    }
    if ($installArguments -notcontains '--source') {
        $installArguments += @('--source','winget')
    }
    $installArguments += @(
        '--silent',
        '--accept-package-agreements','--accept-source-agreements','--disable-interactivity'
    )

    try {
        Write-PowerHubLog -Message "Kuruluyor: $($item.Name)" -Color Cyan
        Write-PowerHubLog -Message "Komut: winget $($installArguments -join ' ')" -Color DarkGray
        $script:wingetExecutable = Resolve-WingetExecutable
        if (-not $script:wingetExecutable) { throw 'winget çalıştırılabilir dosyası bulunamadı.' }
        $script:installProcess = Start-Process -FilePath $script:wingetExecutable -ArgumentList $installArguments -PassThru -NoNewWindow
        $script:installTimer.Start()
    } catch {
        Write-PowerHubLog -Message "Başlatma hatası ($($item.Name)): $($_.Exception.Message)" -Color Red
        [void]$script:installResults.Add([pscustomobject]@{ Name=$item.Name; Success=$false; Manual=$false; Code=-1 })
        $script:installIndex++
        Start-NextInstall
    }
}

$script:installTimer.Add_Tick({
    if (-not $script:installProcess) { return }
    $script:installProcess.Refresh()
    if (-not $script:installProcess.HasExited) { return }

    $script:installTimer.Stop()
    $item = $script:installQueue[$script:installIndex]
    $script:installProcess.WaitForExit()
    $exitCode = [int]$script:installProcess.ExitCode
    if ($exitCode -eq 0) {
        Write-PowerHubLog -Message "Başarılı: $($item.Name), çıkış kodu: 0" -Color Green
    } else {
        Write-PowerHubLog -Message "Başarısız: $($item.Name), çıkış kodu: $exitCode" -Color Red
    }
    [void]$script:installResults.Add([pscustomobject]@{ Name=$item.Name; Success=($exitCode -eq 0); Manual=$false; Code=$exitCode })
    $script:installProcess.Dispose()
    $script:installProcess = $null
    $script:installIndex++
    Start-NextInstall
})

$controls.InstallButton.Add_Click({
    $script:installQueue = @($apps | Where-Object { $_.IsSelected -and -not $_.IsWebResource -and $_.Operation -ne 'None' } | ForEach-Object {
        $sourceIndex = if ($_.PSObject.Properties['InstallArguments']) { [Array]::IndexOf([object[]]@($_.InstallArguments), '--source') } else { -1 }
        $packageSource = if ($sourceIndex -ge 0 -and ($sourceIndex + 1) -lt @($_.InstallArguments).Count) { @($_.InstallArguments)[$sourceIndex + 1] } else { 'winget' }
        [pscustomobject]@{
            Name = $_.Name
            Id = $_.Id
            Action = if ($_.PSObject.Properties['Action']) { $_.Action } else { 'Winget' }
            Url = if ($_.PSObject.Properties['Url']) { $_.Url } else { $null }
            InstallArguments = if ($_.PSObject.Properties['InstallArguments']) { @($_.InstallArguments) } else { $null }
            Operation = $_.Operation
            PackageSource = $packageSource
        }
    })
    if ($script:installQueue.Count -eq 0) { return }

    Write-Host ''
    Write-PowerHubLog -Message "$($script:installQueue.Count) uygulamalık kurulum kuyruğu başlatıldı." -Color White
    $script:installIndex = 0
    $script:installResults = [Collections.ArrayList]::new()
    $script:isInstalling = $true
    $controls.InstallButton.IsEnabled = $false
    $controls.SelectAllButton.IsEnabled = $false
    $controls.InstallProgress.Visibility = 'Visible'
    $controls.InstallProgress.Value = 0
    $controls.ActivityText.Text = 'Kurulum hazırlanıyor...'
    Start-NextInstall
})

function Set-WingetCardState {
    param([ValidateSet('Ready','Missing','Installing','Error')][string]$State)

    switch ($State) {
        'Ready' {
            $script:wingetReady = $true
            $controls.WingetCard.Cursor = [Windows.Input.Cursors]::Arrow
            $controls.WingetCard.BorderBrush = New-ColorBrush '#46515A'
            $controls.WingetIconBox.Background = New-ColorBrush '#214B35'
            $controls.WingetIconBox.BorderBrush = New-ColorBrush '#346A4D'
            $controls.WingetIcon.Text = '✓'
            $controls.WingetIcon.Foreground = New-ColorBrush '#7EE2A8'
            $controls.WingetStatus.Text = 'winget hazır'
            $controls.WingetDetail.Text = 'Paket yöneticisi çevrimiçi'
            $controls.WingetBadge.Background = New-ColorBrush '#204A32'
            $controls.WingetBadge.BorderBrush = New-ColorBrush '#346A4D'
            $controls.WingetBadgeDot.Fill = New-ColorBrush '#67DB95'
            $controls.WingetBadgeText.Text = 'AKTİF'
            $controls.WingetBadgeText.Foreground = New-ColorBrush '#7EE2A8'
        }
        'Missing' {
            $script:wingetReady = $false
            $controls.WingetCard.Cursor = [Windows.Input.Cursors]::Hand
            $controls.WingetCard.BorderBrush = New-ColorBrush '#B07A38'
            $controls.WingetIconBox.Background = New-ColorBrush '#594523'
            $controls.WingetIconBox.BorderBrush = New-ColorBrush '#8A682F'
            $controls.WingetIcon.Text = '↓'
            $controls.WingetIcon.Foreground = New-ColorBrush '#FFD58A'
            $controls.WingetStatus.Text = 'winget kur'
            $controls.WingetDetail.Text = 'Otomatik kurmak için tıklayın'
            $controls.WingetBadge.Background = New-ColorBrush '#58441F'
            $controls.WingetBadge.BorderBrush = New-ColorBrush '#8A682F'
            $controls.WingetBadgeDot.Fill = New-ColorBrush '#F5BC5A'
            $controls.WingetBadgeText.Text = 'KUR'
            $controls.WingetBadgeText.Foreground = New-ColorBrush '#FFD58A'
        }
        'Installing' {
            $script:wingetReady = $false
            $controls.WingetCard.Cursor = [Windows.Input.Cursors]::Wait
            $controls.WingetCard.BorderBrush = New-ColorBrush '#278DD1'
            $controls.WingetIconBox.Background = New-ColorBrush '#174C70'
            $controls.WingetIconBox.BorderBrush = New-ColorBrush '#278DD1'
            $controls.WingetIcon.Text = '…'
            $controls.WingetIcon.Foreground = New-ColorBrush '#BEE7FF'
            $controls.WingetStatus.Text = 'winget kuruluyor'
            $controls.WingetDetail.Text = 'App Installer indiriliyor'
            $controls.WingetBadge.Background = New-ColorBrush '#174C70'
            $controls.WingetBadge.BorderBrush = New-ColorBrush '#278DD1'
            $controls.WingetBadgeDot.Fill = New-ColorBrush '#61C7FF'
            $controls.WingetBadgeText.Text = 'BEKLE'
            $controls.WingetBadgeText.Foreground = New-ColorBrush '#BEE7FF'
        }
        'Error' {
            $script:wingetReady = $false
            $controls.WingetCard.Cursor = [Windows.Input.Cursors]::Hand
            $controls.WingetCard.BorderBrush = New-ColorBrush '#A95454'
            $controls.WingetIconBox.Background = New-ColorBrush '#542E32'
            $controls.WingetIconBox.BorderBrush = New-ColorBrush '#A95454'
            $controls.WingetIcon.Text = '!'
            $controls.WingetIcon.Foreground = New-ColorBrush '#FFAAAA'
            $controls.WingetStatus.Text = 'kurulum tamamlanamadı'
            $controls.WingetDetail.Text = 'Store gerekmez • yeniden denemek için tıklayın'
            $controls.WingetBadge.Background = New-ColorBrush '#542E32'
            $controls.WingetBadge.BorderBrush = New-ColorBrush '#A95454'
            $controls.WingetBadgeDot.Fill = New-ColorBrush '#FF7777'
            $controls.WingetBadgeText.Text = 'TEKRAR'
            $controls.WingetBadgeText.Foreground = New-ColorBrush '#FFAAAA'
        }
    }
    $controls.WingetStatus.Foreground = [Windows.Media.Brushes]::White
}

$script:wingetReady = $false
$script:wingetInstallProcess = $null
$script:wingetInstallResultFile = $null
$script:wingetInstallTimer = [Windows.Threading.DispatcherTimer]::new()
$script:wingetInstallTimer.Interval = [TimeSpan]::FromMilliseconds(500)

$script:wingetInstallTimer.Add_Tick({
    if (-not $script:wingetInstallProcess) { return }
    $script:wingetInstallProcess.Refresh()
    if (-not $script:wingetInstallProcess.HasExited) { return }

    $script:wingetInstallTimer.Stop()
    $script:wingetInstallProcess.WaitForExit()
    $processExitCode = [int]$script:wingetInstallProcess.ExitCode
    $script:wingetInstallProcess.Dispose()
    $script:wingetInstallProcess = $null
    $exitCode = $processExitCode
    if ($script:wingetInstallResultFile -and (Test-Path -LiteralPath $script:wingetInstallResultFile)) {
        try { $exitCode = [int](Get-Content -LiteralPath $script:wingetInstallResultFile -Raw -ErrorAction Stop).Trim() } catch {}
        Remove-Item -LiteralPath $script:wingetInstallResultFile -Force -ErrorAction SilentlyContinue
    }
    $script:wingetInstallResultFile = $null
    $wingetCommand = Resolve-WingetExecutable

    if ($exitCode -eq 0 -and $wingetCommand) {
        $script:wingetExecutable = $wingetCommand
        Write-PowerHubLog -Message "winget başarıyla kuruldu: $wingetCommand" -Color Green
        $controls.ActivityText.Text = 'winget başarıyla kuruldu. Uygulamalar kurulabilir.'
        Set-WingetCardState -State Ready
        Update-SelectionStatus
        Start-SystemScan
    } else {
        Write-PowerHubLog -Message "Store bağımsız winget kurulumu tamamlanamadı (kod: $exitCode)." -Color Red
        $controls.ActivityText.Text = 'Kurulum tamamlanamadı. Ayrıntılar terminalde; durum kartından yeniden deneyin.'
        Set-WingetCardState -State Error
    }
})

$controls.WingetCard.Add_MouseLeftButtonUp({
    if ($script:wingetReady -or $script:wingetInstallProcess) { return }

    Set-WingetCardState -State Installing
    $controls.ActivityText.Text = 'Microsoft App Installer indiriliyor ve winget kuruluyor...'
    Write-PowerHubLog -Message 'winget otomatik kurulumu başlatıldı.' -Color Cyan

    $installerScript = @'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Save-PowerHubFile {
    param([string]$Uri, [string]$Destination)
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & $curl.Source -L --fail --retry 3 --connect-timeout 20 --output $Destination $Uri
        if ($LASTEXITCODE -ne 0) { throw "İndirme başarısız: $Uri" }
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $Destination
    }
}

function Confirm-PowerHubHash {
    param([string]$FilePath, [string]$HashFile)
    $expected = ((Get-Content -LiteralPath $HashFile -Raw).Trim() -split '\s+')[0].ToUpperInvariant()
    $stream = [IO.File]::OpenRead($FilePath)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { $actual = ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '').ToUpperInvariant() }
    finally { $sha256.Dispose(); $stream.Dispose() }
    if ($expected -ne $actual) { throw "SHA256 doğrulaması başarısız: $(Split-Path $FilePath -Leaf)" }
}

$nativeArchitecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$packageArchitecture = switch ($nativeArchitecture.ToUpperInvariant()) {
    'ARM64' { 'arm64' }
    'AMD64' { 'x64' }
    default { 'x86' }
}
$workDirectory = Join-Path $env:TEMP ("PowerHub-WinGet-" + [Guid]::NewGuid().ToString('N'))
$dependencyArchive = Join-Path $workDirectory 'DesktopAppInstaller_Dependencies.zip'
$dependencyHash = Join-Path $workDirectory 'DesktopAppInstaller_Dependencies.txt'
$dependencyDirectory = Join-Path $workDirectory 'Dependencies'
$appInstallerBundle = Join-Path $workDirectory 'Microsoft.DesktopAppInstaller.msixbundle'
$appInstallerHash = Join-Path $workDirectory 'Microsoft.DesktopAppInstaller.txt'
$releaseBase = 'https://github.com/microsoft/winget-cli/releases/latest/download'
$result = 1

Write-Host "[PowerHub] Store bağımsız WinGet kurulumu hazırlanıyor ($packageArchitecture)..." -ForegroundColor Cyan
try {
    New-Item -ItemType Directory -Path $workDirectory -Force | Out-Null

    Write-Host '[PowerHub] Resmî bağımlılık paketi indiriliyor...' -ForegroundColor Cyan
    Save-PowerHubFile "$releaseBase/DesktopAppInstaller_Dependencies.zip" $dependencyArchive
    Save-PowerHubFile "$releaseBase/DesktopAppInstaller_Dependencies.txt" $dependencyHash
    Confirm-PowerHubHash $dependencyArchive $dependencyHash

    Write-Host '[PowerHub] Microsoft App Installer indiriliyor...' -ForegroundColor Cyan
    Save-PowerHubFile "$releaseBase/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" $appInstallerBundle
    Save-PowerHubFile "$releaseBase/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.txt" $appInstallerHash
    Confirm-PowerHubHash $appInstallerBundle $appInstallerHash

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $dependencyDirectory) { Remove-Item -LiteralPath $dependencyDirectory -Recurse -Force }
    [IO.Compression.ZipFile]::ExtractToDirectory($dependencyArchive, $dependencyDirectory)
    $architectureDirectory = Join-Path $dependencyDirectory $packageArchitecture
    $dependencyPackages = @(Get-ChildItem -LiteralPath $architectureDirectory -File | Where-Object Extension -in @('.appx','.msix'))
    if ($dependencyPackages.Count -eq 0) { throw "Mimariye uygun bağımlılık bulunamadı: $packageArchitecture" }

    foreach ($dependency in $dependencyPackages) {
        Write-Host "[PowerHub] Bağımlılık hazır: $($dependency.BaseName)" -ForegroundColor DarkCyan
    }

    Write-Host '[PowerHub] Microsoft App Installer ve bağımlılıkları kuruluyor...' -ForegroundColor Cyan
    Add-AppxPackage -Path $appInstallerBundle -DependencyPath @($dependencyPackages.FullName) -ForceApplicationShutdown -ErrorAction Stop
    Start-Sleep -Seconds 2

    $installedPackage = Get-AppxPackage -Name Microsoft.DesktopAppInstaller |
        Sort-Object Version -Descending |
        Select-Object -First 1
    $wingetPath = if ($installedPackage) { Join-Path $installedPackage.InstallLocation 'winget.exe' } else { $null }
    if (-not $wingetPath -or -not (Test-Path -LiteralPath $wingetPath)) { throw 'winget.exe kurulum sonrasında bulunamadı.' }

    Write-Host '[PowerHub] WinGet çalışması doğrulanıyor...' -ForegroundColor Cyan
    & $wingetPath --version
    if ($LASTEXITCODE -ne 0) { throw "winget doğrulaması başarısız (kod: $LASTEXITCODE)." }

    Write-Host '[PowerHub] Paket kaynakları hazırlanıyor...' -ForegroundColor Cyan
    & $wingetPath source reset --force
    & $wingetPath source update
    Write-Host '[PowerHub] WinGet ve tüm çalışma bağımlılıkları hazır.' -ForegroundColor Green
    $result = 0
} catch {
    Write-Host "[PowerHub] WinGet kurulum hatası: $($_.Exception.Message)" -ForegroundColor Red
    $result = 1
} finally {
    Remove-Item -LiteralPath $workDirectory -Recurse -Force -ErrorAction SilentlyContinue
    if ($env:POWERHUB_WINGET_RESULT_FILE) {
        [IO.File]::WriteAllText($env:POWERHUB_WINGET_RESULT_FILE, [string]$result)
    }
}
exit $result
'@
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($installerScript))
    try {
        $script:wingetInstallResultFile = Join-Path $env:TEMP ("PowerHub-WinGet-result-{0}.txt" -f [Guid]::NewGuid().ToString('N'))
        $env:POWERHUB_WINGET_RESULT_FILE = $script:wingetInstallResultFile
        $script:wingetInstallProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
            '-NoProfile','-ExecutionPolicy','Bypass','-OutputFormat','Text','-EncodedCommand',$encodedCommand
        ) -PassThru -NoNewWindow
        Remove-Item Env:\POWERHUB_WINGET_RESULT_FILE -ErrorAction SilentlyContinue
        $script:wingetInstallTimer.Start()
    } catch {
        Remove-Item Env:\POWERHUB_WINGET_RESULT_FILE -ErrorAction SilentlyContinue
        if ($script:wingetInstallResultFile) { Remove-Item -LiteralPath $script:wingetInstallResultFile -Force -ErrorAction SilentlyContinue }
        $script:wingetInstallResultFile = $null
        Write-PowerHubLog -Message "winget kurulumu başlatılamadı: $($_.Exception.Message)" -Color Red
        $controls.ActivityText.Text = 'Store bağımsız kurulum başlatılamadı. Durum kartından yeniden deneyin.'
        Set-WingetCardState -State Error
    }
})

$winget = Resolve-WingetExecutable
if ($winget) {
    $script:wingetExecutable = $winget
    Write-PowerHubLog -Message "winget hazır: $winget" -Color Green
    Set-WingetCardState -State Ready
} else {
    Write-PowerHubLog -Message 'winget bulunamadı. Kurulum için durum kartına tıklayın.' -Color Yellow
    Set-WingetCardState -State Missing
    foreach ($app in @($apps | Where-Object { -not $_.IsWebResource })) { Set-AppInstallState -App $app -State Unknown }
    $controls.SystemScanBadge.Background = New-ColorBrush '#574422'
    $controls.SystemScanBadgeText.Foreground = New-ColorBrush '#FFD58A'
    $controls.SystemScanBadgeText.Text = '●  Tarama bekliyor'
    $controls.SystemScanBadge.ToolTip = 'Akıllı tarama için önce WinGet kurulmalıdır'
    $controls.ActivityText.Text = 'winget kurmak için sol alttaki durum kartına tıklayın.'
}

Update-AppList
Update-SelectionStatus
Set-PowerHubWindowLayout
Write-PowerHubLog -Message 'PowerHub hazır. Kurulum günlükleri bu terminalde gösterilecek.' -Color Cyan
if ($winget) { Start-SystemScan }
$window.Add_Closed({
    $script:systemScanTimer.Stop()
    if ($script:systemScanProcess -and -not $script:systemScanProcess.HasExited) {
        Stop-Process -Id $script:systemScanProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($script:systemScanResultFile) { Remove-Item -LiteralPath $script:systemScanResultFile -Force -ErrorAction SilentlyContinue }
})
$window.ShowDialog() | Out-Null
