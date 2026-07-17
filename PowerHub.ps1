#requires -Version 5.1

<#
    PowerHub - Windows için sade ve modern toplu uygulama kurucusu.
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
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern IntPtr LoadImage(IntPtr instance, string name, uint type, int width, int height, uint loadFlags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr SendMessage(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = true)] private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);
    [DllImport("dwmapi.dll", PreserveSig = true)] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int valueSize);
    public static void EnablePerMonitorDpi() {
        try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch { }
    }
    public static void ConfigureApplicationIdentity() {
        try { SetCurrentProcessExplicitAppUserModelID("byGOG.PowerHub"); } catch { }
    }
    public static void ApplyWindowIcon(IntPtr hwnd, string iconPath) {
        if (hwnd == IntPtr.Zero || String.IsNullOrWhiteSpace(iconPath)) return;
        try {
            const uint IMAGE_ICON = 1;
            const uint LR_LOADFROMFILE = 0x0010;
            const uint WM_SETICON = 0x0080;
            IntPtr largeIcon = LoadImage(IntPtr.Zero, iconPath, IMAGE_ICON, 32, 32, LR_LOADFROMFILE);
            IntPtr smallIcon = LoadImage(IntPtr.Zero, iconPath, IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
            if (largeIcon != IntPtr.Zero) SendMessage(hwnd, WM_SETICON, new IntPtr(1), largeIcon);
            if (smallIcon != IntPtr.Zero) SendMessage(hwnd, WM_SETICON, IntPtr.Zero, smallIcon);
        } catch { }
    }
    public static void ApplyFluentWindow(IntPtr hwnd) {
        if (hwnd == IntPtr.Zero) return;
        try {
            int enabled = 1;
            int rounded = 2;
            int mica = 2;
            DwmSetWindowAttribute(hwnd, 20, ref enabled, sizeof(int));
            DwmSetWindowAttribute(hwnd, 33, ref rounded, sizeof(int));
            DwmSetWindowAttribute(hwnd, 38, ref mica, sizeof(int));
        } catch { }
    }
    public static void ApplyDarkTitleBar(IntPtr hwnd, bool enabled) {
        if (hwnd == IntPtr.Zero) return;
        try {
            int value = enabled ? 1 : 0;
            DwmSetWindowAttribute(hwnd, 20, ref value, sizeof(int));
        } catch { }
    }
}
'@

[PowerHubWindowLayout]::EnablePerMonitorDpi()
[PowerHubWindowLayout]::ConfigureApplicationIdentity()

$script:powerHubIconPath = @(
    (Join-Path $PSScriptRoot 'assets\powerhub-logo.ico'),
    (Join-Path $PSScriptRoot 'PowerHub\assets\powerhub-logo.ico')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

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
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerHub" Width="980" Height="900" MinWidth="860" MinHeight="700"
        WindowStartupLocation="Manual" Background="{DynamicResource PageBg}"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType" TextOptions.TextHintingMode="Fixed"
        RenderOptions.ClearTypeHint="Enabled" UseLayoutRounding="True" SnapsToDevicePixels="True"
        AutomationProperties.Name="PowerHub uygulama ve paket merkezi"
        AutomationProperties.HelpText="Klavye yardımı için F1 tuşuna basın"
        KeyboardNavigation.TabNavigation="Cycle" KeyboardNavigation.ControlTabNavigation="Cycle">
    <Window.Resources>
        <SolidColorBrush x:Key="Primary" Color="#38BDF8"/>
        <SolidColorBrush x:Key="Ink" Color="#F8FAFC"/>
        <SolidColorBrush x:Key="Muted" Color="#94A3B8"/>
        <LinearGradientBrush x:Key="PageBg" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#0B1118" Offset="0"/>
            <GradientStop Color="#101923" Offset="0.58"/>
            <GradientStop Color="#111827" Offset="1"/>
        </LinearGradientBrush>
        <SolidColorBrush x:Key="SidebarBg" Color="#0D141C"/>
        <SolidColorBrush x:Key="Surface" Color="#171E27"/>
        <SolidColorBrush x:Key="SurfaceRaised" Color="#1C2530"/>
        <SolidColorBrush x:Key="CardBg" Color="#18212B"/>
        <SolidColorBrush x:Key="CardBorder" Color="#2D3A48"/>
        <SolidColorBrush x:Key="SoftBg" Color="#202C38"/>
        <SolidColorBrush x:Key="SoftText" Color="#BAE6FD"/>
        <SolidColorBrush x:Key="ActionBg" Color="#222D38"/>
        <SolidColorBrush x:Key="ActionHover" Color="#263E49"/>
        <SolidColorBrush x:Key="ActionBorder" Color="#425366"/>
        <SolidColorBrush x:Key="ActionIcon" Color="#BAE6FD"/>
        <SolidColorBrush x:Key="DangerBg" Color="#302126"/>
        <SolidColorBrush x:Key="DangerBorder" Color="#6B3338"/>
        <SolidColorBrush x:Key="DangerIcon" Color="#FF9B9B"/>
        <SolidColorBrush x:Key="SubtleBorder" Color="#334252"/>
        <SolidColorBrush x:Key="InputBg" Color="#15202B"/>
        <SolidColorBrush x:Key="OverlayBg" Color="#E6080A0C"/>
        <LinearGradientBrush x:Key="HeaderBg" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#1C2530" Offset="0"/>
            <GradientStop Color="#18232F" Offset="1"/>
        </LinearGradientBrush>
        <DropShadowEffect x:Key="CardShadow" Color="#020617" BlurRadius="10" ShadowDepth="2" Opacity="0.16"/>
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
                                                <Border Background="#526273" CornerRadius="2" Margin="3,1"/>
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
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.88"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#A5F3FC"/>
                                <Setter TargetName="ButtonBorder" Property="BorderThickness" Value="2"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.62"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Foreground" Value="{DynamicResource Ink}"/>
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
                                CornerRadius="7" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="NavBorder" Property="Background" Value="{DynamicResource SoftBg}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="NavBorder" Property="Background" Value="{DynamicResource SurfaceRaised}"/>
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
            <Setter Property="Width" Value="32"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Padding" Value="0"/>
            <Setter Property="Background" Value="{DynamicResource ActionBg}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource ActionBorder}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Foreground" Value="{DynamicResource ActionIcon}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="IconSurface" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="IconSurface" Property="Background" Value="{DynamicResource ActionHover}"/>
                                <Setter TargetName="IconSurface" Property="BorderBrush" Value="#38BDF8"/>
                                <Setter Property="Foreground" Value="{DynamicResource Primary}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="IconSurface" Property="Background" Value="#0D659E"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="IconSurface" Property="BorderBrush" Value="#A5F3FC"/>
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
            <Setter Property="Foreground" Value="{DynamicResource Ink}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource SubtleBorder}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="9"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="AboutSurface" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="10" Padding="{TemplateBinding Padding}" Background="{DynamicResource Surface}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="AboutSurface" Property="BorderBrush" Value="#258CC0"/><Setter TargetName="AboutSurface" Property="Background" Value="{DynamicResource SoftBg}"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="AboutSurface" Property="Background" Value="{DynamicResource SurfaceRaised}"/></Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="AboutSurface" Property="BorderBrush" Value="#A5F3FC"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="20"/>
            <Setter Property="Height" Value="20"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Width="20" Height="20">
                            <Border x:Name="CheckBorder" Background="{DynamicResource Surface}" BorderBrush="#526273"
                                    BorderThickness="1" CornerRadius="5"/>
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
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="CheckBorder" Property="BorderBrush" Value="#CFFAFE"/>
                                <Setter TargetName="CheckBorder" Property="BorderThickness" Value="2"/>
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

        <Canvas x:Name="ThemeVisualLayer" Grid.Column="1" IsHitTestVisible="False" ClipToBounds="True" Opacity="0">
            <Ellipse x:Name="ThemeGlowOne" Width="420" Height="420" Canvas.Right="-115" Canvas.Top="-150" Opacity="0.28">
                <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#6DB8FF" Offset="0"/><GradientStop Color="#006DB8FF" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
                <Ellipse.Effect><BlurEffect Radius="42"/></Ellipse.Effect>
            </Ellipse>
            <Ellipse x:Name="ThemeGlowTwo" Width="360" Height="360" Canvas.Left="-120" Canvas.Bottom="-125" Opacity="0.2">
                <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#A78BFA" Offset="0"/><GradientStop Color="#00A78BFA" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
                <Ellipse.Effect><BlurEffect Radius="48"/></Ellipse.Effect>
            </Ellipse>
        </Canvas>

        <Border x:Name="Sidebar" Grid.Column="0" BorderBrush="{DynamicResource SubtleBorder}" BorderThickness="0,0,1,0" Background="{DynamicResource SidebarBg}">
            <Grid Margin="18,20">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <StackPanel Orientation="Horizontal" Margin="8,0,0,25">
                    <Border Width="44" Height="44" CornerRadius="10" SnapsToDevicePixels="True" ClipToBounds="True">
                        <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#0F2747" Offset="0"/><GradientStop Color="#0759BC" Offset="0.72"/><GradientStop Color="#089DD5" Offset="1"/></LinearGradientBrush></Border.Background>
                        <Viewbox Stretch="Uniform" Margin="5">
                            <Canvas Width="64" Height="64" SnapsToDevicePixels="True">
                                <Path Fill="#F8FAFC" Data="F0 M16,10 L35,10 C48,10 55,18 55,30 C55,42 48,49 35,49 L27,49 L27,56 L16,56 Z M27,20 L27,39 L35,39 C41,39 44,36 44,30 C44,24 41,20 35,20 Z"/>
                                <Path Stroke="#22D3EE" StrokeThickness="4.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Data="M22,49 L35,36 L35,29"/>
                                <Ellipse Canvas.Left="30.5" Canvas.Top="21" Width="9" Height="9" Fill="#67E8F9" Stroke="#E0F2FE" StrokeThickness="1.5"/>
                            </Canvas>
                        </Viewbox>
                    </Border>
                    <StackPanel Margin="11,0,0,0">
                        <TextBlock Text="PowerHub" Foreground="{DynamicResource Ink}" FontWeight="SemiBold" FontSize="18"/>
                        <TextBlock Text="Uygulama merkezi" Foreground="{DynamicResource Muted}" FontSize="12" Margin="0,2,0,0"/>
                    </StackPanel>
                </StackPanel>

                <Grid Grid.Row="1" Margin="8,0,8,8">
                    <TextBlock Text="KATEGORİLER" Foreground="{DynamicResource Muted}" FontSize="10.5" FontWeight="Bold"/>
                    <Border Height="1" Background="{DynamicResource CardBorder}" Margin="78,6,0,0"/>
                </Grid>
                <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Margin="0,0,0,8">
                    <ScrollViewer.Resources><Style TargetType="ScrollBar" BasedOn="{StaticResource SlimScrollBar}"/></ScrollViewer.Resources>
                    <StackPanel x:Name="CategoryPanel"/>
                </ScrollViewer>

                <Button x:Name="UpdateCenterButton" Grid.Row="3" Height="58" Style="{StaticResource AboutNavButton}" Margin="0,4,0,0"
                        ToolTip="Yüklü paketlerdeki güncellemeleri tara ve yönet" AutomationProperties.Name="Güncelleme Merkezi">
                    <Grid Width="183">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/><ColumnDefinition Width="20"/></Grid.ColumnDefinitions>
                        <Border Width="32" Height="32" CornerRadius="12" Background="#8A5B17" BorderBrush="#B9822B" BorderThickness="1">
                            <TextBlock Text="&#xE895;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#FFD58A" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,4,0">
                            <TextBlock Text="Güncelleme Merkezi" Foreground="{DynamicResource Ink}" FontSize="12" FontWeight="SemiBold"/>
                            <TextBlock x:Name="UpdateCenterNavDetail" Text="Paketleri tara ve yükselt" Foreground="#C8AC7F" FontSize="10" Margin="0,3,0,0"/>
                        </StackPanel>
                        <TextBlock Grid.Column="2" Text="&#xE72A;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#FFD58A" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Grid>
                </Button>

                <Button x:Name="SecurityCenterButton" Grid.Row="4" Height="58" Style="{StaticResource AboutNavButton}" Margin="0,8,0,0"
                        ToolTip="Sistem ve PowerHub güvenlik durumunu denetle" AutomationProperties.Name="Güvenlik Merkezi">
                    <Grid Width="183">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/><ColumnDefinition Width="20"/></Grid.ColumnDefinitions>
                        <Border Width="32" Height="32" CornerRadius="12" Background="#174B39" BorderBrush="#2E7658" BorderThickness="1">
                            <TextBlock Text="&#xE72E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#6EE7B7" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,4,0">
                            <TextBlock Text="Güvenlik Merkezi" Foreground="{DynamicResource Ink}" FontSize="12" FontWeight="SemiBold"/>
                            <TextBlock x:Name="SecurityCenterNavDetail" Text="Denetim bekleniyor" Foreground="#86C9A8" FontSize="10" Margin="0,3,0,0"/>
                        </StackPanel>
                        <TextBlock Grid.Column="2" Text="&#xE72A;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#6EE7B7" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Grid>
                </Button>

                <Button x:Name="FailureCenterButton" Grid.Row="5" Height="58" Style="{StaticResource AboutNavButton}" Margin="0,8,0,0" Visibility="Collapsed"
                        ToolTip="Başarısız paket işlemlerini incele ve yeniden dene" AutomationProperties.Name="Başarısız İşlemler Merkezi">
                    <Grid Width="183">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/><ColumnDefinition Width="20"/></Grid.ColumnDefinitions>
                        <Border Width="32" Height="32" CornerRadius="12" Background="#543136" BorderBrush="#7D4449" BorderThickness="1">
                            <TextBlock Text="!" Foreground="#FFAAAA" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,4,0">
                            <TextBlock Text="Başarısız İşlemler" Foreground="#F1F8FC" FontSize="12" FontWeight="SemiBold"/>
                            <TextBlock x:Name="FailureCenterNavDetail" Text="Kayıt bulunmuyor" Foreground="#D39A9F" FontSize="10" Margin="0,3,0,0"/>
                        </StackPanel>
                        <TextBlock Grid.Column="2" Text="&#xE72A;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#FFAAAA" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Grid>
                </Button>

                <Button x:Name="AboutButton" Grid.Row="6" Height="58" Style="{StaticResource AboutNavButton}" Margin="0,8,0,0"
                        ToolTip="PowerHub bilgilerini ve bağlantılarını göster" AutomationProperties.Name="PowerHub hakkında">
                    <Grid Width="183">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/><ColumnDefinition Width="20"/></Grid.ColumnDefinitions>
                        <Border Width="32" Height="32" CornerRadius="12" Background="#0EA5E9">
                            <TextBlock Text="&#xE946;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="White" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,4,0">
                            <TextBlock Text="Hakkında" Foreground="{DynamicResource Ink}" FontSize="13" FontWeight="SemiBold"/>
                            <TextBlock Text="PowerHub • byGOG" Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,3,0,0"/>
                        </StackPanel>
                        <TextBlock Grid.Column="2" Text="&#xE72A;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#72CFF4" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Grid>
                </Button>

                <Border x:Name="WingetCard" Grid.Row="7" Height="58" Background="{DynamicResource Surface}" BorderBrush="{DynamicResource SubtleBorder}" BorderThickness="1"
                        CornerRadius="10" Padding="9,7" Margin="0,8,0,0" ToolTip="winget durumunu ve kurulum motorunu gösterir"
                        Focusable="True" AutomationProperties.Name="WinGet paket yöneticisi durumu"
                        AutomationProperties.HelpText="WinGet eksikse Enter veya Boşluk tuşuyla kurulumu başlatın">
                    <Grid Width="183" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="42"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="50"/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name="WingetIconBox" Grid.RowSpan="2" Width="32" Height="32" Background="#123B2C" BorderBrush="#236747" BorderThickness="1" CornerRadius="12" VerticalAlignment="Center">
                            <TextBlock x:Name="WingetIcon" Text="✓" Foreground="#6EE7B7" FontSize="14" FontWeight="Bold"
                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock x:Name="WingetStatus" Grid.Column="1" Text="winget kontrol ediliyor" Foreground="{DynamicResource Ink}"
                                   FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" Margin="2,0,5,0"/>
                        <TextBlock x:Name="WingetDetail" Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="2" Text="Paket yöneticisi çevrimiçi"
                                   Foreground="{DynamicResource Muted}" FontSize="10" Margin="2,3,0,0" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                        <Border x:Name="WingetBadge" Grid.Column="2" Background="#123A2A" BorderBrush="#236747" BorderThickness="1"
                                CornerRadius="12" Padding="6,3" HorizontalAlignment="Right" VerticalAlignment="Center">
                            <StackPanel Orientation="Horizontal">
                                <Ellipse x:Name="WingetBadgeDot" Width="4" Height="4" Fill="#67DB95" VerticalAlignment="Center" Margin="0,0,4,0"/>
                                <TextBlock x:Name="WingetBadgeText" Text="AKTİF" Foreground="#6EE7B7" FontSize="9" FontWeight="Bold"/>
                            </StackPanel>
                        </Border>
                    </Grid>
                </Border>
            </Grid>
        </Border>

        <Grid x:Name="MainWorkspace" Grid.Column="1" Margin="24,18,24,18">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Border x:Name="HeaderBanner" CornerRadius="14" Padding="20,17" Background="{DynamicResource HeaderBg}" BorderBrush="{DynamicResource SubtleBorder}" BorderThickness="1"
                    Effect="{DynamicResource CardShadow}">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="54"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="300"/>
                    </Grid.ColumnDefinitions>
                    <Border Grid.ColumnSpan="3" Height="2" VerticalAlignment="Top" Margin="-20,-17,-20,0" CornerRadius="12,12,0,0">
                        <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#22D3EE" Offset="0"/><GradientStop Color="#38BDF8" Offset="0.45"/><GradientStop Color="#8B5CF6" Offset="1"/></LinearGradientBrush></Border.Background>
                    </Border>
                    <Border Grid.Row="0" Grid.Column="0" Width="44" Height="44" CornerRadius="10"
                            VerticalAlignment="Center" HorizontalAlignment="Left">
                        <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#0EA5E9" Offset="0"/><GradientStop Color="#6366F1" Offset="1"/></LinearGradientBrush></Border.Background>
                        <Grid>
                            <Rectangle Width="21" Height="17" Fill="Transparent" Stroke="White" StrokeThickness="1.8" RadiusX="3" RadiusY="3"/>
                            <Path Data="M 15 17 L 23 17 M 19 13 L 19 21" Stroke="White" StrokeThickness="1.8"
                                  StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                        </Grid>
                    </Border>
                    <StackPanel Grid.Row="0" Grid.Column="1" VerticalAlignment="Center">
                        <TextBlock Text="POWERHUB  /  WINGET" FontSize="9.5" FontWeight="Bold" Foreground="#7DD3FC" Margin="0,0,0,3"/>
                        <TextBlock Text="Paket merkezi" FontSize="25" FontWeight="SemiBold" Foreground="{DynamicResource Ink}"/>
                        <TextBlock Text="Keşfet, seç ve tek akışta kur."
                                   Foreground="{DynamicResource Muted}" FontSize="14" Margin="0,5,0,0"/>
                    </StackPanel>
                    <Grid Grid.Row="0" Grid.Column="2" VerticalAlignment="Center">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="40"/></Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Background="{DynamicResource InputBg}" BorderBrush="{DynamicResource SubtleBorder}"
                                BorderThickness="1" CornerRadius="9" Height="42">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="38"/><ColumnDefinition Width="*"/><ColumnDefinition Width="34"/></Grid.ColumnDefinitions>
                                <TextBlock Text="⌕" FontSize="22" Foreground="#94A3B8" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                <TextBlock x:Name="SearchPlaceholder" Grid.Column="1" Text="Uygulama veya kaynak ara..." Foreground="#64748B"
                                           FontSize="13" VerticalAlignment="Center" IsHitTestVisible="False"/>
                                <TextBox x:Name="SearchBox" Grid.Column="1" BorderThickness="0" Background="Transparent"
                                         VerticalContentAlignment="Center" FontSize="14" Foreground="{DynamicResource Ink}" CaretBrush="{DynamicResource Primary}"
                                         ToolTip="Uygulama ara (Ctrl+F). Yazdığınız sorguyu Enter ile WinGet'te ara."
                                         AutomationProperties.Name="Uygulama veya kaynak ara"
                                         AutomationProperties.HelpText="Arama alanına gitmek için Ctrl+F kullanın. Yazdığınız sorgu Enter ile WinGet terminal aramasında açılır."
                                         Margin="0,0,8,0"/>
                                <Button x:Name="SearchClearButton" Grid.Column="2" Content="×" Width="26" Height="26" Padding="0"
                                        Background="Transparent" Foreground="#94A3B8" FontSize="18" ToolTip="Aramayı temizle"
                                        AutomationProperties.Name="Aramayı temizle" Visibility="Collapsed"/>
                            </Grid>
                        </Border>
                        <Button x:Name="ThemeButton" Grid.Column="1" Width="34" Height="34"
                                HorizontalAlignment="Right" VerticalAlignment="Center" Padding="0"
                                Background="{DynamicResource SoftBg}" Foreground="{DynamicResource SoftText}"
                                BorderBrush="{DynamicResource SubtleBorder}" BorderThickness="1"
                                ToolTip="Görünüm: Otomatik — değiştirmek için tıklayın"
                                AutomationProperties.Name="Görünüm temasını seç">
                            <TextBlock x:Name="ThemeButtonIcon" Text="&#xE790;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"
                                       FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Button>
                        <Popup x:Name="ThemePopup" Placement="Bottom" StaysOpen="False" AllowsTransparency="True" PopupAnimation="Fade">
                            <Border Width="158" Margin="0,6,0,0" Padding="7" CornerRadius="10"
                                    Background="{DynamicResource SurfaceRaised}" BorderBrush="{DynamicResource SubtleBorder}" BorderThickness="1">
                                <Border.Effect><DropShadowEffect Color="#000000" BlurRadius="18" ShadowDepth="5" Opacity="0.45"/></Border.Effect>
                                <StackPanel>
                                    <TextBlock Text="GÖRÜNÜM" Foreground="{DynamicResource Muted}" FontSize="9" FontWeight="Bold" Margin="8,3,8,6"/>
                                    <Button x:Name="ThemeAutoButton" Tag="Auto" Content="◐   Otomatik" HorizontalContentAlignment="Left" Padding="10,7" Margin="0,1" Background="Transparent" Foreground="{DynamicResource Ink}"/>
                                    <Button x:Name="ThemeDarkButton" Tag="Dark" Content="☾   Koyu" HorizontalContentAlignment="Left" Padding="10,7" Margin="0,1" Background="Transparent" Foreground="{DynamicResource Ink}"/>
                                    <Button x:Name="ThemeLightButton" Tag="Light" Content="☀   Açık" HorizontalContentAlignment="Left" Padding="10,7" Margin="0,1" Background="Transparent" Foreground="{DynamicResource Ink}"/>
                                </StackPanel>
                            </Border>
                        </Popup>
                    </Grid>
                    <Grid Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="2" Margin="0,13,0,0">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                            <Border Background="{DynamicResource SoftBg}" CornerRadius="9" Padding="7,4" Margin="0,0,5,0">
                                <TextBlock x:Name="TotalAppBadgeText" Text="0 uygulama" Foreground="{DynamicResource SoftText}" FontSize="10.5" FontWeight="SemiBold"/>
                            </Border>
                            <Border x:Name="SystemScanBadge" Background="#123629" CornerRadius="9" Padding="7,4">
                                <TextBlock x:Name="SystemScanBadgeText" Text="●  Sistem hazır" Foreground="#6EE7B7" FontSize="10.5" FontWeight="SemiBold"/>
                            </Border>
                            <Border Background="{DynamicResource SoftBg}" CornerRadius="9" Padding="7,4" Margin="5,0,0,0">
                                <TextBlock x:Name="CategoryBadgeText" Text="0 kategori" Foreground="{DynamicResource Ink}" FontSize="10.5" FontWeight="SemiBold"/>
                            </Border>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                            <TextBlock Text="WINGET KATALOĞU" Foreground="{DynamicResource Muted}" FontSize="9.5" FontWeight="Bold" VerticalAlignment="Center"/>
                            <Ellipse Width="4" Height="4" Fill="{DynamicResource CardBorder}" Margin="10,0" VerticalAlignment="Center"/>
                            <TextBlock Text="GÜVENLİ • REKLAMSIZ" Foreground="#39C77A" FontSize="9.5" FontWeight="Bold" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Grid>
                </Grid>
            </Border>

            <Grid Grid.Row="1" Margin="0,15,0,10">
                <TextBlock x:Name="SectionTitle" Text="Tüm uygulamalar" FontSize="18" FontWeight="SemiBold" Foreground="{DynamicResource Ink}" VerticalAlignment="Center"/>
                <Button x:Name="KeyboardHelpButton" Content="⌨  F1" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,104,0"
                        Background="{DynamicResource SurfaceRaised}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1" Foreground="{DynamicResource SoftText}" FontSize="10" Padding="8,4"
                        ToolTip="Klavye kısayollarını göster" AutomationProperties.Name="Klavye kısayollarını göster"/>
                <Border HorizontalAlignment="Right" Background="{DynamicResource Surface}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1" CornerRadius="12" Padding="10,5">
                    <TextBlock x:Name="ResultCount" Foreground="{DynamicResource Ink}" FontSize="11" FontWeight="SemiBold"/>
                </Border>
            </Grid>

            <ListBox x:Name="AppList" Grid.Row="2" BorderThickness="0" Background="Transparent"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled" KeyboardNavigation.TabNavigation="Once"
                     AutomationProperties.Name="Uygulama listesi" AutomationProperties.HelpText="Ok tuşlarıyla gezinin, Boşluk ile seçin, Enter ile ayrıntıları açın">
                <ListBox.Resources>
                    <Style TargetType="ScrollBar">
                        <Setter Property="Width" Value="9"/>
                        <Setter Property="Background" Value="Transparent"/>
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="ScrollBar">
                                    <Grid Background="#141B23">
                                        <Track x:Name="PART_Track" IsDirectionReversed="True">
                                            <Track.DecreaseRepeatButton>
                                                <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0"/>
                                            </Track.DecreaseRepeatButton>
                                            <Track.Thumb>
                                                <Thumb>
                                                    <Thumb.Template>
                                                        <ControlTemplate TargetType="Thumb">
                                                            <Border Background="#526273" CornerRadius="2" Margin="2,0"/>
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
                        <Setter Property="Focusable" Value="True"/>
                        <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
                        <Setter Property="AutomationProperties.Name" Value="{Binding AccessibleName}"/>
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="ListBoxItem">
                                    <Border x:Name="KeyboardFocusBorder" BorderBrush="Transparent" BorderThickness="2" CornerRadius="11">
                                        <ContentPresenter/>
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsKeyboardFocusWithin" Value="True">
                                            <Setter TargetName="KeyboardFocusBorder" Property="BorderBrush" Value="#A5F3FC"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Setter.Value>
                        </Setter>
                    </Style>
                </ListBox.ItemContainerStyle>
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <Border x:Name="CardBorder" Height="72" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1"
                                CornerRadius="12" Padding="0" ClipToBounds="True" SnapsToDevicePixels="True" Cursor="Hand"
                                Effect="{DynamicResource CardShadow}">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="4"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border x:Name="AccentBar" Background="{Binding Color}"/>
                                <Grid Grid.Column="1" Margin="12,7,11,7">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="46"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="34"/><ColumnDefinition Width="34"/><ColumnDefinition Width="34"/><ColumnDefinition Width="32"/></Grid.ColumnDefinitions>
                                    <Border Width="38" Height="38" Background="Transparent" VerticalAlignment="Center">
                                        <Grid>
                                            <Image Source="{Binding Logo}" Width="36" Height="36" Stretch="Uniform"
                                                   RenderOptions.BitmapScalingMode="HighQuality"
                                                   HorizontalAlignment="Center" VerticalAlignment="Center" SnapsToDevicePixels="True"/>
                                            <TextBlock Text="{Binding Initial}" Opacity="{Binding InitialOpacity}" Foreground="{Binding Color}" FontWeight="Bold" FontSize="17"
                                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>
                                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,8,0">
                                        <TextBlock Text="{Binding Name}" Foreground="{DynamicResource Ink}" FontWeight="SemiBold" FontSize="15"
                                                   TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Text="{Binding Description}" Foreground="{DynamicResource Muted}" FontSize="12" Margin="0,3,0,0"
                                                   TextTrimming="CharacterEllipsis"/>
                                    </StackPanel>
                                    <Border Grid.Column="2" Background="{Binding SourceBackground}" CornerRadius="12" Padding="7,4" Margin="8,0,7,0"
                                            VerticalAlignment="Center" ToolTip="{Binding StatusDetail}">
                                        <TextBlock Text="{Binding SourceLabel}" Foreground="{Binding SourceForeground}" FontSize="9.5" FontWeight="Bold"/>
                                    </Border>
                                    <Button x:Name="DetailButton" Grid.Column="3" Style="{StaticResource IconButton}" ToolTip="Uygulama ayrıntılarını göster"
                                            AutomationProperties.Name="{Binding Name, StringFormat={}{0} ayrıntılarını göster}" VerticalAlignment="Center" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE946;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="16"
                                                   HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Button>
                                    <Button x:Name="WebsiteButton" Grid.Column="4" Tag="{Binding WebsiteUrl}" Style="{StaticResource IconButton}"
                                            Visibility="{Binding WebsiteVisibility}" ToolTip="Resmî siteyi aç" AutomationProperties.Name="Resmî siteyi aç"
                                            VerticalAlignment="Center" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE71B;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="17"
                                                   HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Button>
                                    <Button x:Name="UninstallButton" Grid.Column="5" Style="{StaticResource IconButton}"
                                            Background="{DynamicResource DangerBg}" BorderBrush="{DynamicResource DangerBorder}"
                                            Visibility="{Binding UninstallVisibility}" ToolTip="Uygulamayı kaldır" AutomationProperties.Name="{Binding Name, StringFormat={}{0} uygulamasını kaldır}"
                                            VerticalAlignment="Center" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE74D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="16"
                                                   Foreground="{DynamicResource DangerIcon}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Button>
                                    <CheckBox x:Name="AppCheck" Grid.Column="6" IsChecked="{Binding IsSelected, Mode=TwoWay}"
                                              Visibility="{Binding CheckVisibility}" AutomationProperties.Name="{Binding Name, StringFormat={}{0} uygulamasını seç}"
                                              VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                </Grid>
                            </Grid>
                        </Border>
                        <DataTemplate.Triggers>
                            <DataTrigger Binding="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=ListBoxItem}}" Value="True">
                                <Setter TargetName="CardBorder" Property="Background" Value="{DynamicResource SoftBg}"/>
                                <Setter TargetName="CardBorder" Property="BorderBrush" Value="{DynamicResource SubtleBorder}"/>
                            </DataTrigger>
                            <DataTrigger Binding="{Binding IsChecked, ElementName=AppCheck}" Value="True">
                                <Setter TargetName="CardBorder" Property="Background" Value="#172F40"/>
                                <Setter TargetName="CardBorder" Property="BorderBrush" Value="#38BDF8"/>
                                <Setter TargetName="CardBorder" Property="BorderThickness" Value="1.5"/>
                            </DataTrigger>
                        </DataTemplate.Triggers>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>

            <Border Grid.Row="3" Background="{DynamicResource SurfaceRaised}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1" CornerRadius="12" Padding="15,11" Margin="0,8,0,0"
                    Effect="{DynamicResource CardShadow}">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock x:Name="SelectionText" Text="Henüz uygulama seçilmedi" Foreground="{DynamicResource Ink}" FontSize="14.5" FontWeight="SemiBold"
                                   AutomationProperties.LiveSetting="Polite"/>
                        <TextBlock x:Name="ActivityText" Text="Kurulacak uygulamaları işaretleyin." Foreground="{DynamicResource Muted}" FontSize="12" Margin="0,4,0,0"
                                   AutomationProperties.LiveSetting="Polite"/>
                        <ProgressBar x:Name="InstallProgress" Height="3" Margin="0,9,18,0" Minimum="0" Maximum="100"
                                     Value="0" Visibility="Collapsed" Foreground="{DynamicResource Primary}" Background="{DynamicResource SoftBg}"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <Button x:Name="QueueViewButton" Content="Kuyruk" Background="{DynamicResource SoftBg}" Foreground="{DynamicResource SoftText}"
                                Margin="0,0,9,0" IsEnabled="False" ToolTip="Kurulum kuyruğunu göster (Ctrl+Q)" AutomationProperties.Name="Kurulum kuyruğunu göster"/>
                        <Button x:Name="SelectAllButton" Content="Görünenleri seç" Background="{DynamicResource SoftBg}" Foreground="{DynamicResource SoftText}"
                                Margin="0,0,9,0" ToolTip="Görünen kartları seç veya seçimi kaldır (Ctrl+A)" AutomationProperties.Name="Görünen uygulamaları seç veya seçimi kaldır"/>
                        <Button x:Name="InstallButton" Content="Kurulumu başlat  →" Background="#0EA5E9" Foreground="White"
                                IsEnabled="False" ToolTip="Seçilenleri kur (Ctrl+Enter)" AutomationProperties.Name="Seçilen paket işlemlerini başlat"/>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>


        <Grid x:Name="AppDetailOverlay" Grid.Column="1" Panel.ZIndex="55" Visibility="Collapsed" Background="#B8080A0C"
              AutomationProperties.Name="Uygulama ayrıntıları" KeyboardNavigation.TabNavigation="Cycle">
            <Border x:Name="AppDetailBackdrop" Background="Transparent"/>
            <Border x:Name="AppDetailDrawer" Width="460" HorizontalAlignment="Right" Background="#111820" BorderBrush="#3C4B5B" BorderThickness="1,0,0,0">
                <Border.Effect><DropShadowEffect Color="#000000" BlurRadius="24" ShadowDepth="7" Opacity="0.64"/></Border.Effect>
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0" Background="#1A222C" BorderBrush="#374655" BorderThickness="0,0,0,1" Padding="20,17">
                        <Grid>
                            <Border Height="2" VerticalAlignment="Top" Margin="-20,-17,-20,0">
                                <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#22D3EE" Offset="0"/><GradientStop Color="#8B5CF6" Offset="1"/></LinearGradientBrush></Border.Background>
                            </Border>
                            <StackPanel>
                                <TextBlock Text="POWERHUB  /  UYGULAMA" Foreground="#67E8F9" FontSize="9.5" FontWeight="Bold"/>
                                <TextBlock Text="Uygulama ayrıntıları" Foreground="White" FontSize="21" FontWeight="SemiBold" Margin="0,4,45,0"/>
                            </StackPanel>
                            <Button x:Name="AppDetailCloseButton" Content="&#xE711;" Width="34" Height="34" Padding="0" HorizontalAlignment="Right" VerticalAlignment="Center"
                                    Style="{StaticResource IconButton}" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" ToolTip="Ayrıntıları kapat"/>
                        </Grid>
                    </Border>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <StackPanel Margin="20,20,20,18">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="68"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Width="54" Height="54" Background="#1E2833" BorderBrush="#3A4958" BorderThickness="1" CornerRadius="12">
                                    <Grid>
                                        <Image x:Name="AppDetailLogo" Width="46" Height="46" Stretch="Uniform" SnapsToDevicePixels="True"/>
                                        <TextBlock x:Name="AppDetailInitial" Text="P" Foreground="#67E8F9" FontSize="21" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Grid>
                                </Border>
                                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                    <TextBlock x:Name="AppDetailName" Text="Uygulama" Foreground="#F5F5F5" FontSize="19" FontWeight="SemiBold" TextWrapping="Wrap"/>
                                    <TextBlock x:Name="AppDetailCategory" Text="Kategori" Foreground="#8FB7CA" FontSize="11" Margin="0,6,0,0"/>
                                </StackPanel>
                            </Grid>
                            <Border x:Name="AppDetailStatusBadge" Background="#263F52" BorderBrush="#36596E" BorderThickness="1" CornerRadius="12" Padding="11,8" Margin="0,18,0,0">
                                <Grid>
                                    <TextBlock Text="PAKET DURUMU" Foreground="#80909A" FontSize="9" FontWeight="Bold"/>
                                    <TextBlock x:Name="AppDetailStatusText" Text="TARANIYOR" Foreground="#7DD3FC" FontSize="11" FontWeight="Bold" HorizontalAlignment="Right"/>
                                </Grid>
                            </Border>
                            <TextBlock x:Name="AppDetailStatusDescription" Text="Paket durumu açıklaması" Foreground="#98A6AE" FontSize="10.5" Margin="1,7,0,0" TextWrapping="Wrap"/>
                            <Grid Margin="0,12,0,0">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Background="#1A222C" BorderBrush="#334150" BorderThickness="1" CornerRadius="12" Padding="11,9">
                                    <StackPanel><TextBlock Text="KURULU SÜRÜM" Foreground="#7F8B94" FontSize="8.5" FontWeight="Bold"/><TextBlock x:Name="AppDetailInstalledVersion" Text="—" Foreground="#F0F4F6" FontSize="13" FontWeight="SemiBold" Margin="0,5,0,0"/></StackPanel>
                                </Border>
                                <Border Grid.Column="2" Background="#1A222C" BorderBrush="#334150" BorderThickness="1" CornerRadius="12" Padding="11,9">
                                    <StackPanel><TextBlock Text="KATALOG SÜRÜMÜ" Foreground="#7F8B94" FontSize="8.5" FontWeight="Bold"/><TextBlock x:Name="AppDetailCatalogVersion" Text="—" Foreground="#7DD3FC" FontSize="13" FontWeight="SemiBold" Margin="0,5,0,0"/></StackPanel>
                                </Border>
                            </Grid>
                            <TextBlock x:Name="AppDetailMetadataState" Text="WinGet ayrıntıları hazırlanıyor..." Foreground="#7F9CAE" FontSize="10" Margin="1,9,0,0"/>
                            <TextBlock Text="AÇIKLAMA" Foreground="#7F8B94" FontSize="9" FontWeight="Bold" Margin="0,21,0,0"/>
                            <TextBlock x:Name="AppDetailDescription" Text="Uygulama açıklaması" Foreground="#C5CDD2" FontSize="12.5" LineHeight="19" TextWrapping="Wrap" Margin="0,7,0,0"/>
                            <TextBlock Text="PAKET BİLGİLERİ" Foreground="#7F8B94" FontSize="9" FontWeight="Bold" Margin="0,22,0,8"/>
                            <Border Background="#1A222C" BorderBrush="#334150" BorderThickness="1" CornerRadius="10" Padding="13,11">
                                <Grid>
                                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="104"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <TextBlock Text="Paket kimliği" Foreground="#8D999F" FontSize="10.5"/>
                                    <TextBlock x:Name="AppDetailId" Grid.Column="1" Text="—" Foreground="#E2E7EA" FontFamily="Cascadia Mono, Consolas" FontSize="10.5" TextWrapping="Wrap"/>
                                    <TextBlock Grid.Row="1" Text="Kaynak" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailSource" Grid.Row="1" Grid.Column="1" Text="WinGet" Foreground="#E2E7EA" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock Grid.Row="2" Text="Kategori" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailMetaCategory" Grid.Row="2" Grid.Column="1" Text="—" Foreground="#E2E7EA" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock Grid.Row="3" Text="Yayıncı" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailPublisher" Grid.Row="3" Grid.Column="1" Text="—" Foreground="#E2E7EA" FontSize="10.5" Margin="0,10,0,0" TextWrapping="Wrap"/>
                                    <TextBlock Grid.Row="4" Text="Geliştirici" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailAuthor" Grid.Row="4" Grid.Column="1" Text="—" Foreground="#E2E7EA" FontSize="10.5" Margin="0,10,0,0" TextWrapping="Wrap"/>
                                    <TextBlock Grid.Row="5" Text="Lisans" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailLicense" Grid.Row="5" Grid.Column="1" Text="—" Foreground="#E2E7EA" FontSize="10.5" Margin="0,10,0,0" TextWrapping="Wrap"/>
                                    <TextBlock Grid.Row="6" Text="Yükleyici türü" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailInstallerType" Grid.Row="6" Grid.Column="1" Text="—" Foreground="#E2E7EA" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock Grid.Row="7" Text="Etiketler" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailTags" Grid.Row="7" Grid.Column="1" Text="—" Foreground="#A9C6D5" FontSize="10" Margin="0,10,0,0" TextWrapping="Wrap"/>
                                    <TextBlock Grid.Row="8" Text="Kaynak deposu" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailRepository" Grid.Row="8" Grid.Column="1" Text="—" Foreground="#7DD3FC" FontSize="10" Margin="0,10,0,0" TextWrapping="Wrap"/>
                                    <TextBlock Grid.Row="9" Text="SHA-256" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailHashStatus" Grid.Row="9" Grid.Column="1" Text="—" Foreground="#6EE7B7" FontSize="10" Margin="0,10,0,0" TextWrapping="Wrap"/>
                                    <TextBlock Grid.Row="10" Text="Yetki kapsamı" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailElevation" Grid.Row="10" Grid.Column="1" Text="—" Foreground="#E2E7EA" FontSize="10.5" Margin="0,10,0,0" TextWrapping="Wrap"/>
                                    <TextBlock Grid.Row="11" Text="Katalog tarihi" Foreground="#8D999F" FontSize="10.5" Margin="0,10,0,0"/>
                                    <TextBlock x:Name="AppDetailCatalogUpdated" Grid.Row="11" Grid.Column="1" Text="—" Foreground="#E2E7EA" FontSize="10.5" Margin="0,10,0,0"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                    <Border Grid.Row="2" Background="#1A222C" BorderBrush="#374655" BorderThickness="0,1,0,0" Padding="16,13">
                        <Grid>
                            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <Button x:Name="AppDetailRemoveButton" Content="Kaldır" Background="#543136" Foreground="#FFAAAA" Visibility="Collapsed" Margin="0,0,8,0"
                                    ToolTip="Uygulamayı bilgisayardan kaldır"/>
                            <Button x:Name="AppDetailWebsiteButton" Grid.Column="1" Content="Resmî site  ↗" Background="#24313D" Foreground="#9EDBF3" HorizontalAlignment="Left"
                                    ToolTip="Uygulamanın resmî sitesini aç"/>
                            <Button x:Name="AppDetailPrimaryButton" Grid.Column="2" Content="Kurulum için seç  →" Background="#0EA5E9" Foreground="White" MinWidth="145"/>
                        </Grid>
                    </Border>
                </Grid>
            </Border>
        </Grid>


        <Grid x:Name="InstallQueueOverlay" Grid.Column="1" Margin="24,18,24,18" Panel.ZIndex="60" Visibility="Collapsed" Background="#A8080A0C"
              AutomationProperties.Name="Kurulum kuyruğu" KeyboardNavigation.TabNavigation="Cycle">
            <Border x:Name="QueueBackdrop" Background="Transparent"/>
            <Border Width="430" HorizontalAlignment="Right" Background="#131A22" BorderBrush="#3C4B5B" BorderThickness="1" CornerRadius="12">
                <Border.Effect><DropShadowEffect Color="#000000" BlurRadius="24" ShadowDepth="7" Opacity="0.6"/></Border.Effect>
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0" Background="#1C2530" BorderBrush="#374655" BorderThickness="0,0,0,1" Padding="18,15">
                        <Grid>
                            <Border Height="2" VerticalAlignment="Top" Margin="-18,-15,-18,0"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#22D3EE" Offset="0"/><GradientStop Color="#8B5CF6" Offset="1"/></LinearGradientBrush></Border.Background></Border>
                            <StackPanel>
                                <TextBlock Text="POWERHUB  /  PAKET İŞLEMLERİ" Foreground="#67E8F9" FontSize="9.5" FontWeight="Bold"/>
                                <TextBlock Text="İşlem kuyruğu" Foreground="White" FontSize="22" FontWeight="SemiBold" Margin="0,4,0,0"/>
                                <TextBlock Text="Paketleri ve işlem durumlarını tek ekrandan izleyin." Foreground="#9DA9B1" FontSize="11.5" Margin="0,4,48,0"/>
                            </StackPanel>
                            <Button x:Name="QueueCloseButton" Content="&#xE711;" Width="34" Height="34" Padding="0" HorizontalAlignment="Right" VerticalAlignment="Top"
                                    Background="#24313D" BorderBrush="#435467" BorderThickness="1" Foreground="#C9D4DA"
                                    FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" ToolTip="Kuyruğu kapat"/>
                        </Grid>
                    </Border>
                    <Border Grid.Row="1" Margin="16,14,16,10" Background="#1A222C" BorderBrush="#334150" BorderThickness="1" CornerRadius="12" Padding="13,10">
                        <Grid>
                            <StackPanel>
                                <TextBlock x:Name="QueueSummaryText" Text="Kuyruk henüz boş" Foreground="#F1F6F9" FontSize="13.5" FontWeight="SemiBold"/>
                                <TextBlock x:Name="QueueDetailText" Text="Kurulacak uygulamaları seçip işlemi başlatın." Foreground="#96A3AC" FontSize="10.5" Margin="0,4,0,0"/>
                            </StackPanel>
                            <Border HorizontalAlignment="Right" VerticalAlignment="Center" Background="#263F52" CornerRadius="12" Padding="8,4">
                                <TextBlock x:Name="QueueCountText" Text="0 PAKET" Foreground="#7DD3FC" FontSize="9" FontWeight="Bold"/>
                            </Border>
                        </Grid>
                    </Border>
                    <ListBox x:Name="InstallQueueList" Grid.Row="2" Margin="16,0,16,0" Background="Transparent" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                        <ListBox.ItemContainerStyle>
                            <Style TargetType="ListBoxItem">
                                <Setter Property="Padding" Value="0"/><Setter Property="Margin" Value="0,0,0,7"/><Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                                <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><ContentPresenter/></ControlTemplate></Setter.Value></Setter>
                            </Style>
                        </ListBox.ItemContainerStyle>
                        <ListBox.ItemTemplate>
                            <DataTemplate>
                                <Border Background="#1C2530" BorderBrush="#374655" BorderThickness="1" CornerRadius="12" Padding="12,10">
                                    <Grid>
                                        <Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <Border Width="20" Height="20" CornerRadius="10" Background="{Binding StatusBackground}" VerticalAlignment="Center">
                                            <TextBlock Text="{Binding StatusIcon}" Foreground="{Binding StatusForeground}" FontSize="10" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="{Binding Name}" Foreground="White" FontSize="12.5" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                                            <TextBlock Text="{Binding Detail}" Foreground="#929FA8" FontSize="10" Margin="0,3,8,0" TextTrimming="CharacterEllipsis"/>
                                        </StackPanel>
                                        <Border Grid.Column="2" Background="{Binding StatusBackground}" CornerRadius="12" Padding="7,4" VerticalAlignment="Center">
                                            <TextBlock Text="{Binding StatusLabel}" Foreground="{Binding StatusForeground}" FontSize="8.5" FontWeight="Bold"/>
                                        </Border>
                                    </Grid>
                                </Border>
                            </DataTemplate>
                        </ListBox.ItemTemplate>
                    </ListBox>
                    <Border Grid.Row="3" Background="#1A222C" BorderBrush="#374655" BorderThickness="0,1,0,0" Padding="16,13">
                        <Grid>
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <StackPanel VerticalAlignment="Center">
                                <TextBlock x:Name="QueueFooterText" Text="Kuyruk beklemede" Foreground="#E4EBEF" FontSize="11.5" FontWeight="SemiBold"/>
                                <ProgressBar x:Name="QueueProgress" Height="3" Margin="0,8,16,0" Minimum="0" Maximum="100" Value="0" Foreground="#22D3EE" Background="#3A3A3A"/>
                            </StackPanel>
                            <StackPanel Grid.Column="1" Orientation="Horizontal">
                                <Button x:Name="QueueRetryButton" Content="Başarısızları dene" Background="#574422" Foreground="#FFD58A" Margin="0,0,8,0" IsEnabled="False"/>
                                <Button x:Name="QueueCancelButton" Content="İptal et" Background="#543136" Foreground="#FFB0B0" IsEnabled="False"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                </Grid>
            </Border>
        </Grid>

        <Grid x:Name="FailureCenterView" Grid.Column="1" Margin="24,18,24,18" Background="#0F141A" Visibility="Collapsed" Panel.ZIndex="24">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Border CornerRadius="12" Padding="18,15" Background="#171E27" BorderBrush="#4B3B3D" BorderThickness="1">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="58"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <Border Grid.ColumnSpan="3" Height="2" VerticalAlignment="Top" Margin="-18,-15,-18,0">
                        <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#E0525C" Offset="0"/><GradientStop Color="#D09335" Offset="0.58"/><GradientStop Color="#38BDF8" Offset="1"/></LinearGradientBrush></Border.Background>
                    </Border>
                    <Border Width="42" Height="42" CornerRadius="10" Background="#543136" BorderBrush="#7D4449" BorderThickness="1">
                        <TextBlock Text="!" Foreground="#FFAAAA" FontSize="20" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Grid.Column="1">
                        <TextBlock Text="POWERHUB  /  İŞLEM GEÇMİŞİ" FontSize="9.5" FontWeight="Bold" Foreground="#FF8F97"/>
                        <TextBlock Text="Başarısız İşlemler Merkezi" FontSize="24" FontWeight="SemiBold" Foreground="{DynamicResource Ink}" Margin="0,3,0,0"/>
                        <TextBlock Text="Hataları inceleyin, güvenli biçimde yeniden veya etkileşimli deneyin." Foreground="{DynamicResource Muted}" FontSize="13" Margin="0,5,0,0"/>
                    </StackPanel>
                    <Button x:Name="FailureBackButton" Grid.Column="2" Content="←  Paket merkezi" Background="#24313D" Foreground="#C8D6E0" VerticalAlignment="Center"/>
                </Grid>
            </Border>

            <Grid Grid.Row="1" Margin="0,15,0,10">
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="İşlem kayıtları" FontSize="18" FontWeight="SemiBold" Foreground="{DynamicResource Ink}" VerticalAlignment="Center"/>
                    <Border Background="#543136" BorderBrush="#7D4449" BorderThickness="1" CornerRadius="12" Padding="9,4" Margin="12,0,0,0">
                        <TextBlock x:Name="FailureCountText" Text="0 başarısız" Foreground="#FFAAAA" FontSize="11" FontWeight="SemiBold"/>
                    </Border>
                </StackPanel>
                <TextBlock x:Name="FailureLastText" Text="Henüz başarısız işlem yok" Foreground="#8D9AA5" FontSize="10.5" HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>

            <Grid Grid.Row="2">
                <Border x:Name="FailureEmptyState" Background="#141B23" BorderBrush="#303D4B" BorderThickness="1" CornerRadius="12">
                    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Border Width="54" Height="54" CornerRadius="27" Background="#123629" BorderBrush="#236747" BorderThickness="1">
                            <TextBlock Text="✓" Foreground="#6EE7B7" FontSize="24" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock Text="Başarısız işlem bulunmuyor" Foreground="White" FontSize="17" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,14,0,0"/>
                        <TextBlock Text="Kurulum, kaldırma ve güncelleme hataları burada saklanır." Foreground="#909CA6" FontSize="12" HorizontalAlignment="Center" Margin="0,6,0,0"/>
                    </StackPanel>
                </Border>
                <ListBox x:Name="FailureList" BorderThickness="0" Background="Transparent" ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.VerticalScrollBarVisibility="Auto">
                    <ListBox.Resources><Style TargetType="ScrollBar" BasedOn="{StaticResource SlimScrollBar}"/></ListBox.Resources>
                    <ListBox.ItemContainerStyle>
                        <Style TargetType="ListBoxItem">
                            <Setter Property="Padding" Value="0"/><Setter Property="Margin" Value="0,0,0,8"/><Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><ContentPresenter/></ControlTemplate></Setter.Value></Setter>
                        </Style>
                    </ListBox.ItemContainerStyle>
                    <ListBox.ItemTemplate>
                        <DataTemplate>
                            <Border Background="#1A222C" BorderBrush="#4A3D3F" BorderThickness="1" CornerRadius="10" Padding="0,11">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="4"/><ColumnDefinition Width="50"/><ColumnDefinition Width="*"/><ColumnDefinition Width="120"/><ColumnDefinition Width="270"/></Grid.ColumnDefinitions>
                                    <Border Background="#E0525C"/>
                                    <Border Grid.Column="1" Width="32" Height="32" CornerRadius="16" Background="#543136" VerticalAlignment="Center">
                                        <TextBlock Text="!" Foreground="#FFAAAA" FontSize="14" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <StackPanel Grid.Column="2" VerticalAlignment="Center" Margin="0,0,12,0">
                                        <TextBlock Text="{Binding Name}" Foreground="White" FontSize="13.5" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Foreground="#929FA8" FontSize="10.5" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"><Run Text="{Binding OperationLabel}"/><Run Text="  •  "/><Run Text="{Binding TimeText}"/><Run Text="  •  "/><Run Text="{Binding Detail}"/></TextBlock>
                                    </StackPanel>
                                    <Border Grid.Column="3" Background="#543136" BorderBrush="#7D4449" BorderThickness="1" CornerRadius="12" Padding="8,5" HorizontalAlignment="Center" VerticalAlignment="Center">
                                        <TextBlock Text="{Binding CodeLabel}" Foreground="#FFAAAA" FontSize="9" FontWeight="Bold"/>
                                    </Border>
                                    <StackPanel Grid.Column="4" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0">
                                        <Button x:Name="FailureWebsiteButton" Content="Site  ↗" Background="#24313D" Foreground="#9EDBF3" Margin="0,0,7,0" Padding="11,7" IsEnabled="{Binding HasWebsite}"/>
                                        <Button x:Name="FailureInteractiveButton" Content="Etkileşimli" Background="#574422" Foreground="#FFD58A" Margin="0,0,7,0" Padding="11,7" IsEnabled="{Binding CanInteractive}"/>
                                        <Button x:Name="FailureRetryButton" Content="Tekrar dene  →" Background="#0EA5E9" Foreground="White" Padding="11,7"/>
                                    </StackPanel>
                                </Grid>
                            </Border>
                        </DataTemplate>
                    </ListBox.ItemTemplate>
                </ListBox>
            </Grid>

            <Border Grid.Row="3" Background="{DynamicResource SurfaceRaised}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1" CornerRadius="10" Padding="15,11" Margin="0,8,0,0">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock x:Name="FailureFooterTitle" Text="Hata geçmişi temiz" Foreground="{DynamicResource Ink}" FontSize="13.5" FontWeight="SemiBold"/>
                        <TextBlock Text="Son 50 başarısız işlem yerel olarak saklanır; başarılı yeniden denemeler listeden kaldırılır." Foreground="{DynamicResource Muted}" FontSize="10.5" Margin="0,4,0,0"/>
                    </StackPanel>
                    <Button x:Name="FailureClearButton" Grid.Column="1" Content="Geçmişi temizle" Background="#543136" Foreground="#FFB0B0" IsEnabled="False"/>
                </Grid>
            </Border>
        </Grid>

        <Grid x:Name="UpdateCenterView" Grid.Column="1" Margin="24,18,24,18" Background="{DynamicResource PageBg}" Visibility="Collapsed" Panel.ZIndex="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Border CornerRadius="12" Padding="18,15" Background="#171E27" BorderBrush="#334150" BorderThickness="1">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="58"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <Border Grid.ColumnSpan="3" Height="2" VerticalAlignment="Top" Margin="-18,-15,-18,0">
                        <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#E4A23A" Offset="0"/><GradientStop Color="#38BDF8" Offset="1"/></LinearGradientBrush></Border.Background>
                    </Border>
                    <Border Width="42" Height="42" CornerRadius="10" Background="#704A16" BorderBrush="#A97529" BorderThickness="1">
                        <TextBlock Text="&#xE895;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#FFD58A" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Grid.Column="1">
                        <TextBlock Text="POWERHUB  /  WINGET" FontSize="9.5" FontWeight="Bold" Foreground="#E9B55D"/>
                        <TextBlock Text="Güncelleme Merkezi" FontSize="24" FontWeight="SemiBold" Foreground="{DynamicResource Ink}" Margin="0,3,0,0"/>
                        <TextBlock Text="Yüklü paketleri denetle, seç ve güvenle güncelle." Foreground="{DynamicResource Muted}" FontSize="13" Margin="0,5,0,0"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="UpdateBackButton" Content="←  Paket merkezi" Background="#24313D" Foreground="#C8D6E0" Margin="0,0,8,0" ToolTip="Uygulama kataloğuna dön"/>
                        <Button x:Name="UpdateRefreshButton" Content="↻  Yeniden tara" Background="#704A16" Foreground="#FFE0A8" ToolTip="Güncellemeleri yeniden denetle"/>
                    </StackPanel>
                </Grid>
            </Border>
            <Grid Grid.Row="1" Margin="0,15,0,10">
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="Kullanılabilir güncellemeler" FontSize="18" FontWeight="SemiBold" Foreground="{DynamicResource Ink}" VerticalAlignment="Center"/>
                    <Border x:Name="UpdateCountBadge" Background="#574422" BorderBrush="#7D632F" BorderThickness="1" CornerRadius="12" Padding="9,4" Margin="12,0,0,0">
                        <TextBlock x:Name="UpdateCountText" Text="Taranıyor" Foreground="#FFD58A" FontSize="11" FontWeight="SemiBold"/>
                    </Border>
                </StackPanel>
                <TextBlock x:Name="UpdateLastScanText" Text="Paket verileri hazırlanıyor..." Foreground="#8D9AA5" FontSize="10.5" HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>
            <Grid Grid.Row="2">
                <Border x:Name="UpdateEmptyState" Background="#141B23" BorderBrush="#303D4B" BorderThickness="1" CornerRadius="12" Visibility="Collapsed">
                    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Border Width="54" Height="54" CornerRadius="27" Background="#123629" BorderBrush="#236747" BorderThickness="1">
                            <TextBlock Text="✓" Foreground="#6EE7B7" FontSize="24" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock Text="Tüm paketler güncel" Foreground="White" FontSize="17" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,14,0,0"/>
                        <TextBlock Text="WinGet yeni bir sürüm bulamadı." Foreground="#909CA6" FontSize="12" HorizontalAlignment="Center" Margin="0,6,0,0"/>
                    </StackPanel>
                </Border>
                <ListBox x:Name="UpdateList" BorderThickness="0" Background="Transparent" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                    <ListBox.ItemContainerStyle>
                        <Style TargetType="ListBoxItem">
                            <Setter Property="Padding" Value="0"/><Setter Property="Margin" Value="0,0,0,7"/><Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><ContentPresenter/></ControlTemplate></Setter.Value></Setter>
                        </Style>
                    </ListBox.ItemContainerStyle>
                    <ListBox.ItemTemplate>
                        <DataTemplate>
                            <Border x:Name="UpdateCard" Height="72" Background="#1C2530" BorderBrush="#3A4958" BorderThickness="1" CornerRadius="12">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="4"/><ColumnDefinition Width="*"/><ColumnDefinition Width="170"/><ColumnDefinition Width="100"/><ColumnDefinition Width="44"/></Grid.ColumnDefinitions>
                                    <Border Background="#D09335"/>
                                    <StackPanel Grid.Column="1" Margin="14,0,12,0" VerticalAlignment="Center">
                                        <TextBlock Text="{Binding Name}" Foreground="White" FontSize="14" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Text="{Binding Id}" Foreground="#8997A3" FontSize="10.5" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="2" VerticalAlignment="Center">
                                        <TextBlock Text="SÜRÜM" Foreground="#7F8B94" FontSize="9" FontWeight="Bold"/>
                                        <TextBlock Foreground="#D4DEE5" FontSize="11.5" Margin="0,5,0,0"><Run Text="{Binding CurrentVersion}"/><Run Text="  →  "/><Run Text="{Binding AvailableVersion}" Foreground="#FFD58A" FontWeight="SemiBold"/></TextBlock>
                                    </StackPanel>
                                    <Border Grid.Column="3" Background="#263F52" CornerRadius="12" Padding="8,4" HorizontalAlignment="Center" VerticalAlignment="Center">
                                        <TextBlock Text="{Binding Source}" Foreground="#7DD3FC" FontSize="9.5" FontWeight="Bold"/>
                                    </Border>
                                    <CheckBox Grid.Column="4" IsChecked="{Binding IsSelected, Mode=TwoWay}" AutomationProperties.Name="{Binding Name}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                            <DataTemplate.Triggers>
                                <DataTrigger Binding="{Binding IsSelected}" Value="True">
                                    <Setter TargetName="UpdateCard" Property="Background" Value="#24313D"/>
                                </DataTrigger>
                            </DataTemplate.Triggers>
                        </DataTemplate>
                    </ListBox.ItemTemplate>
                </ListBox>
            </Grid>
            <Border Grid.Row="3" Background="{DynamicResource SurfaceRaised}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1" CornerRadius="10" Padding="15,11" Margin="0,8,0,0">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock x:Name="UpdateSelectionText" Text="Güncelleme taraması bekleniyor" Foreground="{DynamicResource Ink}" FontSize="14.5" FontWeight="SemiBold"/>
                        <TextBlock x:Name="UpdateActivityText" Text="WinGet paketleri denetlenecek." Foreground="{DynamicResource Muted}" FontSize="12" Margin="0,4,0,0"/>
                        <ProgressBar x:Name="UpdateProgress" Height="3" Margin="0,9,18,0" Minimum="0" Maximum="100" Value="0" Visibility="Collapsed" Foreground="#D09335" Background="#3B3326"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <Button x:Name="UpdateSelectAllButton" Content="Tümünü seç" Background="#24313D" Foreground="#FFD58A" Margin="0,0,9,0" IsEnabled="False"/>
                        <Button x:Name="UpdateInstallButton" Content="Seçilenleri güncelle  →" Background="#B8781E" Foreground="White" IsEnabled="False"/>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>

        <Grid x:Name="SecurityCenterView" Grid.Column="1" Margin="24,18,24,18" Background="{DynamicResource PageBg}" Visibility="Collapsed" Panel.ZIndex="22">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Border CornerRadius="12" Padding="18,15" Background="#171E27" BorderBrush="#334150" BorderThickness="1">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="58"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <Border Grid.ColumnSpan="3" Height="2" VerticalAlignment="Top" Margin="-18,-15,-18,0">
                        <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#39C77A" Offset="0"/><GradientStop Color="#38BDF8" Offset="0.58"/><GradientStop Color="#8B5CF6" Offset="1"/></LinearGradientBrush></Border.Background>
                    </Border>
                    <Border Width="42" Height="42" CornerRadius="10" Background="#174B39" BorderBrush="#2E7658" BorderThickness="1">
                        <TextBlock Text="&#xE72E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#6EE7B7" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Grid.Column="1">
                        <TextBlock Text="POWERHUB  /  GÜVENLİK" FontSize="9.5" FontWeight="Bold" Foreground="#67D69B"/>
                        <TextBlock Text="Güvenlik Merkezi" FontSize="24" FontWeight="SemiBold" Foreground="{DynamicResource Ink}" Margin="0,3,0,0"/>
                        <TextBlock Text="Sistem korumasını, paket kaynaklarını ve katalog bütünlüğünü denetle." Foreground="{DynamicResource Muted}" FontSize="13" Margin="0,5,0,0"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="SecurityBackButton" Content="←  Paket merkezi" Background="#24313D" Foreground="#C8D6E0" Margin="0,0,8,0"/>
                        <Button x:Name="SecurityRefreshButton" Content="↻  Yeniden denetle" Background="#174B39" Foreground="#A3F0C2"/>
                    </StackPanel>
                </Grid>
            </Border>

            <Border Grid.Row="1" Background="#141B23" BorderBrush="#334150" BorderThickness="1" CornerRadius="12" Padding="16,13" Margin="0,14,0,10">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="74"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <Border x:Name="SecurityScoreBadge" Width="58" Height="58" CornerRadius="29" Background="#123629" BorderBrush="#236747" BorderThickness="2">
                        <TextBlock x:Name="SecurityScoreText" Text="—" Foreground="#6EE7B7" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                        <TextBlock x:Name="SecuritySummaryText" Text="Güvenlik denetimi başlatılmaya hazır" Foreground="White" FontSize="15" FontWeight="SemiBold"/>
                        <TextBlock x:Name="SecuritySummaryDetail" Text="Windows koruması ve PowerHub yapılandırması kontrol edilecek." Foreground="#929FA8" FontSize="11" Margin="0,5,0,0"/>
                    </StackPanel>
                    <TextBlock x:Name="SecurityLastScanText" Grid.Column="2" Text="Henüz denetlenmedi" Foreground="#84939E" FontSize="10.5" VerticalAlignment="Center"/>
                </Grid>
            </Border>

            <ListBox x:Name="SecurityCheckList" Grid.Row="2" BorderThickness="0" Background="Transparent"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.VerticalScrollBarVisibility="Auto">
                <ListBox.Resources><Style TargetType="ScrollBar" BasedOn="{StaticResource SlimScrollBar}"/></ListBox.Resources>
                <ListBox.ItemContainerStyle>
                    <Style TargetType="ListBoxItem">
                        <Setter Property="Padding" Value="0"/><Setter Property="Margin" Value="0,0,0,7"/><Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                        <Setter Property="IsHitTestVisible" Value="False"/>
                        <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><ContentPresenter/></ControlTemplate></Setter.Value></Setter>
                    </Style>
                </ListBox.ItemContainerStyle>
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <Border MinHeight="68" Background="#1A222C" BorderBrush="#434343" BorderThickness="1" CornerRadius="10" Padding="0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="4"/><ColumnDefinition Width="54"/><ColumnDefinition Width="*"/><ColumnDefinition Width="130"/></Grid.ColumnDefinitions>
                                <Border Background="{Binding Accent}"/>
                                <Border Grid.Column="1" Width="34" Height="34" CornerRadius="17" Background="{Binding IconBackground}" VerticalAlignment="Center">
                                    <TextBlock Text="{Binding Icon}" Foreground="{Binding Foreground}" FontSize="15" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <StackPanel Grid.Column="2" VerticalAlignment="Center" Margin="0,1,8,1">
                                    <TextBlock Text="{Binding Name}" Foreground="White" FontSize="13.5" FontWeight="SemiBold"/>
                                    <TextBlock Text="{Binding Detail}" Foreground="#929FA8" FontSize="10.5" Margin="0,4,8,0"
                                               TextWrapping="Wrap" TextTrimming="None" MaxHeight="32" LineHeight="15" ToolTip="{Binding Detail}"/>
                                </StackPanel>
                                <Border Grid.Column="3" Background="{Binding StatusBackground}" BorderBrush="{Binding StatusBorder}" BorderThickness="1" CornerRadius="12" Padding="9,5" HorizontalAlignment="Center" VerticalAlignment="Center">
                                    <TextBlock Text="{Binding StatusLabel}" Foreground="{Binding Foreground}" FontSize="9" FontWeight="Bold"/>
                                </Border>
                            </Grid>
                        </Border>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>

            <Border Grid.Row="3" Background="{DynamicResource SurfaceRaised}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1" CornerRadius="10" Padding="15,11" Margin="0,8,0,0">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="Savunma katmanlarını güncel tutun" Foreground="{DynamicResource Ink}" FontSize="13.5" FontWeight="SemiBold"/>
                        <TextBlock Text="PowerHub yalnızca durumu raporlar; güvenlik ayarlarını izinsiz değiştirmez." Foreground="{DynamicResource Muted}" FontSize="10.5" Margin="0,4,0,0"/>
                    </StackPanel>
                    <Button x:Name="OpenWindowsSecurityButton" Grid.Column="1" Content="Windows Güvenliği  ↗" Background="#174B39" Foreground="#A3F0C2" ToolTip="Windows Güvenliği uygulamasını aç"/>
                </Grid>
            </Border>
        </Grid>

        <Grid x:Name="KeyboardHelpOverlay" Grid.ColumnSpan="2" Panel.ZIndex="130" Visibility="Collapsed" Background="#E6080A0C"
              AutomationProperties.Name="Klavye kısayolları" KeyboardNavigation.TabNavigation="Cycle">
            <Border x:Name="KeyboardHelpBackdrop" Background="Transparent"/>
            <Border x:Name="KeyboardHelpCard" Width="610" HorizontalAlignment="Center" VerticalAlignment="Center"
                    Background="#0F141A" BorderBrush="#3F6678" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                <Border.Effect><DropShadowEffect Color="#000000" BlurRadius="30" ShadowDepth="8" Opacity="0.72"/></Border.Effect>
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0" Background="#1A222C" BorderBrush="#374655" BorderThickness="0,0,0,1" Padding="20,17">
                        <Grid>
                            <Grid.ColumnDefinitions><ColumnDefinition Width="48"/><ColumnDefinition Width="*"/><ColumnDefinition Width="40"/></Grid.ColumnDefinitions>
                            <Border Width="38" Height="38" CornerRadius="10" Background="#174A63" BorderBrush="#287BA0" BorderThickness="1">
                                <TextBlock Text="⌨" Foreground="#CFFAFE" FontSize="19" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="POWERHUB  /  ERİŞİLEBİLİRLİK" Foreground="#7DD3FC" FontSize="9.5" FontWeight="Bold"/>
                                <TextBlock Text="Klavye kısayolları" Foreground="White" FontSize="21" FontWeight="SemiBold" Margin="0,4,0,0"/>
                            </StackPanel>
                            <Button x:Name="KeyboardHelpCloseButton" Grid.Column="2" Content="&#xE711;" Width="34" Height="34" Padding="0"
                                    Style="{StaticResource IconButton}" ToolTip="Klavye yardımını kapat" AutomationProperties.Name="Klavye yardımını kapat"/>
                        </Grid>
                    </Border>
                    <Grid Grid.Row="1" Margin="20,18">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <StackPanel>
                            <TextBlock Text="GEZİNME" Foreground="#BAE6FD" FontSize="10" FontWeight="Bold" Margin="0,0,0,9"/>
                            <TextBlock Text="Tab / Shift+Tab     Denetimler arasında ilerle" Foreground="#E2E8F0" FontSize="12" Margin="0,0,0,9"/>
                            <TextBlock Text="F6                         Ana bölgeler arasında geç" Foreground="#E2E8F0" FontSize="12" Margin="0,0,0,9"/>
                            <TextBlock Text="↑  ↓                       Listelerde gezin" Foreground="#E2E8F0" FontSize="12" Margin="0,0,0,9"/>
                            <TextBlock Text="Enter                    Uygulama ayrıntılarını aç" Foreground="#E2E8F0" FontSize="12"/>
                        </StackPanel>
                        <StackPanel Grid.Column="2">
                            <TextBlock Text="İŞLEMLER" Foreground="#BAE6FD" FontSize="10" FontWeight="Bold" Margin="0,0,0,9"/>
                            <TextBlock Text="Ctrl+F / Ctrl+K       Aramaya odaklan" Foreground="#E2E8F0" FontSize="12" Margin="0,0,0,9"/>
                            <TextBlock Text="Enter                    Yazılanı WinGet'te ara" Foreground="#E2E8F0" FontSize="12" Margin="0,0,0,9"/>
                            <TextBlock Text="Boşluk                  Uygulamayı seç / kaldır" Foreground="#E2E8F0" FontSize="12" Margin="0,0,0,9"/>
                            <TextBlock Text="Ctrl+A                   Görünenlerin tümünü seç" Foreground="#E2E8F0" FontSize="12" Margin="0,0,0,9"/>
                            <TextBlock Text="Ctrl+Enter             Seçilen işlemleri başlat" Foreground="#E2E8F0" FontSize="12" Margin="0,0,0,9"/>
                            <TextBlock Text="Ctrl+Q                  Kurulum kuyruğunu aç" Foreground="#E2E8F0" FontSize="12" Margin="0,0,0,9"/>
                            <TextBlock Text="Esc / F1                 Kapat / bu yardımı göster" Foreground="#E2E8F0" FontSize="12"/>
                        </StackPanel>
                    </Grid>
                    <Border Grid.Row="2" Background="#1A222C" BorderBrush="#374655" BorderThickness="0,1,0,0" Padding="20,13">
                        <TextBlock Text="İpucu: Odaklanan denetim açık mavi çerçeveyle gösterilir. Ekran okuyucu durum mesajları otomatik duyurulur."
                                   Foreground="#AAB7C0" FontSize="10.5" TextWrapping="Wrap"/>
                    </Border>
                </Grid>
            </Border>
        </Grid>

        <Grid x:Name="UninstallConfirmOverlay" Grid.ColumnSpan="2" Panel.ZIndex="120" Visibility="Collapsed" Background="#E6080A0C"
              AutomationProperties.Name="Uygulamayı kaldırma onayı" KeyboardNavigation.TabNavigation="Cycle">
            <Border x:Name="UninstallConfirmBackdrop" Background="Transparent"/>
            <Border Width="500" HorizontalAlignment="Center" VerticalAlignment="Center" Background="#0F141A"
                    BorderBrush="#425366" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                <Border.Effect><DropShadowEffect Color="#000000" BlurRadius="28" ShadowDepth="8" Opacity="0.7"/></Border.Effect>
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0" Background="#1A222C" BorderBrush="#374655" BorderThickness="0,0,0,1" Padding="20,18">
                        <Grid>
                            <Grid.ColumnDefinitions><ColumnDefinition Width="52"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                            <Border Grid.ColumnSpan="2" Height="2" VerticalAlignment="Top" Margin="-20,-18,-20,0">
                                <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#E85D5D" Offset="0"/><GradientStop Color="#B43B55" Offset="1"/></LinearGradientBrush></Border.Background>
                            </Border>
                            <Border Width="40" Height="40" CornerRadius="10" Background="#542E32" BorderBrush="#8B454C" BorderThickness="1">
                                <TextBlock Text="&#xE74D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#FFAAAA" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="POWERHUB  /  KALDIRMA" Foreground="#FF969E" FontSize="9.5" FontWeight="Bold"/>
                                <TextBlock Text="Uygulamayı kaldır" Foreground="White" FontSize="21" FontWeight="SemiBold" Margin="0,4,0,0"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                    <StackPanel Grid.Row="1" Margin="20,18,20,18">
                        <TextBlock x:Name="UninstallConfirmAppName" Text="Uygulama" Foreground="#F2F2F2" FontSize="16" FontWeight="SemiBold"/>
                        <TextBlock x:Name="UninstallConfirmDetail" Text="Bu uygulama bilgisayarınızdan kaldırılacak." Foreground="#A7B0B7" FontSize="12" Margin="0,7,0,0" TextWrapping="Wrap"/>
                        <Border Background="#312729" BorderBrush="#5A3A3E" BorderThickness="1" CornerRadius="12" Padding="12,10" Margin="0,16,0,0">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="26"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <TextBlock Text="&#xE7BA;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#FFB0B0" FontSize="14" VerticalAlignment="Top"/>
                                <TextBlock Grid.Column="1" Text="Uygulama ayarları ve yerel verileri kaldırma programının kurallarına göre etkilenebilir." Foreground="#D3B7BA" FontSize="10.5" TextWrapping="Wrap"/>
                            </Grid>
                        </Border>
                    </StackPanel>
                    <Border Grid.Row="2" Background="#1A222C" BorderBrush="#374655" BorderThickness="0,1,0,0" Padding="20,14">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                            <Button x:Name="UninstallCancelButton" Content="Vazgeç" Background="#363636" Foreground="#D8E0E5" Margin="0,0,9,0" MinWidth="96"/>
                            <Button x:Name="UninstallConfirmButton" Content="Kaldır  →" Background="#A8444C" Foreground="White" MinWidth="112"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </Border>
        </Grid>

        <Grid x:Name="AboutOverlay" Grid.ColumnSpan="2" Panel.ZIndex="100" Visibility="Collapsed" Background="{DynamicResource OverlayBg}"
              AutomationProperties.Name="PowerHub hakkında" KeyboardNavigation.TabNavigation="Cycle">
            <Border x:Name="AboutBackdrop" Background="Transparent"/>
            <Border x:Name="AboutCard" Width="620" HorizontalAlignment="Center" VerticalAlignment="Center"
                    Background="#0F141A" BorderBrush="#464646" BorderThickness="1" CornerRadius="12" ClipToBounds="True">
                <Border.Effect><DropShadowEffect Color="#000000" BlurRadius="28" ShadowDepth="8" Opacity="0.68"/></Border.Effect>
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="132"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0" Background="#171E27" BorderBrush="#334150" BorderThickness="0,0,0,1">
                        <Grid Margin="24,0">
                            <Border Height="2" VerticalAlignment="Top" Margin="-24,0"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#22D3EE" Offset="0"/><GradientStop Color="#22D3EE" Offset="0.64"/><GradientStop Color="#8B5CF6" Offset="1"/></LinearGradientBrush></Border.Background></Border>
                            <Grid VerticalAlignment="Center">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="62"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <Border Width="54" Height="54" CornerRadius="12" SnapsToDevicePixels="True" ClipToBounds="True">
                                    <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#0F2747" Offset="0"/><GradientStop Color="#0759BC" Offset="0.72"/><GradientStop Color="#089DD5" Offset="1"/></LinearGradientBrush></Border.Background>
                                    <Viewbox Stretch="Uniform" Margin="6">
                                        <Canvas Width="64" Height="64" SnapsToDevicePixels="True">
                                            <Path Fill="#F8FAFC" Data="F0 M16,10 L35,10 C48,10 55,18 55,30 C55,42 48,49 35,49 L27,49 L27,56 L16,56 Z M27,20 L27,39 L35,39 C41,39 44,36 44,30 C44,24 41,20 35,20 Z"/>
                                            <Path Stroke="#22D3EE" StrokeThickness="4.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Data="M22,49 L35,36 L35,29"/>
                                            <Ellipse Canvas.Left="30.5" Canvas.Top="21" Width="9" Height="9" Fill="#67E8F9" Stroke="#E0F2FE" StrokeThickness="1.5"/>
                                        </Canvas>
                                    </Viewbox>
                                </Border>
                                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                    <TextBlock Text="POWERHUB  /  HAKKINDA" Foreground="#67E8F9" FontSize="9.5" FontWeight="Bold"/>
                                    <TextBlock Text="PowerHub" Foreground="White" FontSize="25" FontWeight="SemiBold" Margin="0,4,0,0"/>
                                    <TextBlock Text="Windows uygulama merkezi" Foreground="#98A6B1" FontSize="11.5" Margin="0,3,0,0"/>
                                </StackPanel>
                                <Button x:Name="AboutCloseButton" Grid.Column="2" Content="&#xE711;" Width="34" Height="34" Padding="0"
                                        Background="#222D38" BorderBrush="#484848" BorderThickness="1" Foreground="#C8D3DA"
                                        FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" ToolTip="Kapat (Esc)"/>
                            </Grid>
                        </Grid>
                    </Border>
                    <StackPanel Grid.Row="1" Margin="24,22,24,24">
                        <TextBlock Text="Uygulamaların için tek merkez." Foreground="White" FontSize="20" FontWeight="SemiBold"/>
                        <TextBlock Text="PowerHub, Windows uygulamalarını keşfetmek, resmî kaynaklara ulaşmak ve güvenli paket kurulumlarını tek merkezden yönetmek için geliştirildi."
                                   Foreground="#AEB8C0" FontSize="12.5" TextWrapping="Wrap" LineHeight="20" Margin="0,9,0,0"/>
                        <Grid Margin="0,18,0,0">
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="8"/><ColumnDefinition Width="*"/><ColumnDefinition Width="8"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                            <Border Grid.Column="0" Background="#171E27" BorderBrush="#334150" BorderThickness="1" CornerRadius="12" Padding="12,10">
                                <StackPanel><TextBlock Text="&#xE896;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#67E8F9" FontSize="15"/><TextBlock Text="WinGet destekli" Foreground="#E8EEF2" FontSize="10.5" FontWeight="SemiBold" Margin="0,7,0,0"/></StackPanel>
                            </Border>
                            <Border Grid.Column="2" Background="#171E27" BorderBrush="#334150" BorderThickness="1" CornerRadius="12" Padding="12,10">
                                <StackPanel><TextBlock Text="&#xE73E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#71D69A" FontSize="15"/><TextBlock Text="Güvenli kaynaklar" Foreground="#E8EEF2" FontSize="10.5" FontWeight="SemiBold" Margin="0,7,0,0"/></StackPanel>
                            </Border>
                            <Border Grid.Column="4" Background="#171E27" BorderBrush="#334150" BorderThickness="1" CornerRadius="12" Padding="12,10">
                                <StackPanel><TextBlock Text="&#xE943;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="#B9AFFF" FontSize="15"/><TextBlock Text="Açık kaynak" Foreground="#E8EEF2" FontSize="10.5" FontWeight="SemiBold" Margin="0,7,0,0"/></StackPanel>
                            </Border>
                        </Grid>
                        <Border Background="#171E27" CornerRadius="12" Padding="15,13" Margin="0,14,0,0" BorderBrush="#334150" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="3"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Background="#22D3EE" CornerRadius="2"/>
                                <TextBlock Grid.Column="1" Foreground="#9EABB4" FontStyle="Italic" FontSize="11.5" TextWrapping="Wrap" LineHeight="18" Margin="12,0,0,0">
                                    <Hyperlink x:Name="SordumLink" NavigateUri="https://www.sordum.net/" Foreground="#67E8F9" TextDecorations="None">Sordum.net</Hyperlink><Run Text=" topluluğunun paylaşım kültürü ve kullanıcı odaklı vizyonundan ilham alınarak hazırlandı."/>
                                </TextBlock>
                            </Grid>
                        </Border>
                        <Grid Margin="0,16,0,0">
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="10"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                            <Button x:Name="AboutByGogButton" Grid.Column="0" Content="byGOG" Background="#222D38" Foreground="#E1E9EE"
                                    BorderBrush="#484848" BorderThickness="1" Padding="13,10" ToolTip="byGOG internet sitesini aç"/>
                            <Button x:Name="AboutGitHubButton" Grid.Column="2" Content="GitHub projesi  →" Background="#174A63" Foreground="#A9E5FF"
                                    BorderBrush="#286783" BorderThickness="1" Padding="13,10" ToolTip="PowerHub GitHub sayfasını aç"/>
                        </Grid>
                        <TextBlock Text="© 2026 byGOG   •   PowerShell ile açık kaynak" Foreground="#75828B" FontSize="9.5" HorizontalAlignment="Center" Margin="0,16,0,0"/>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.Add_SourceInitialized({
    try {
        $windowHelper = [Windows.Interop.WindowInteropHelper]::new($window)
        [PowerHubWindowLayout]::ApplyFluentWindow($windowHelper.Handle)
        [PowerHubWindowLayout]::ApplyDarkTitleBar($windowHelper.Handle, ($script:resolvedTheme -ne 'Light'))
        if ($script:powerHubIconPath) {
            [PowerHubWindowLayout]::ApplyWindowIcon($windowHelper.Handle, [IO.Path]::GetFullPath($script:powerHubIconPath))
        }
    } catch { }
})

$controls = @{}
@('Sidebar','ThemeVisualLayer','MainWorkspace','HeaderBanner','CategoryPanel','WingetCard','WingetIconBox','WingetIcon','WingetStatus','WingetDetail','WingetBadge','WingetBadgeDot','WingetBadgeText','TotalAppBadgeText','CategoryBadgeText','SystemScanBadge','SystemScanBadgeText','SearchBox','SearchPlaceholder','SearchClearButton','KeyboardHelpButton','KeyboardHelpOverlay','KeyboardHelpBackdrop','KeyboardHelpCard','KeyboardHelpCloseButton','SectionTitle','ResultCount','AppList','SelectionText',
  'ThemeButton','ThemeButtonIcon','ThemePopup','ThemeAutoButton','ThemeDarkButton','ThemeLightButton',
  'ActivityText','InstallProgress','SelectAllButton','InstallButton','QueueViewButton','InstallQueueOverlay','QueueBackdrop','QueueCloseButton','InstallQueueList','QueueSummaryText','QueueDetailText','QueueCountText','QueueFooterText','QueueProgress','QueueRetryButton','QueueCancelButton','FailureCenterButton','FailureCenterNavDetail','FailureCenterView','FailureBackButton','FailureCountText','FailureLastText','FailureEmptyState','FailureList','FailureFooterTitle','FailureClearButton','UpdateCenterButton','UpdateCenterNavDetail','UpdateCenterView','UpdateBackButton','UpdateRefreshButton','UpdateCountBadge','UpdateCountText','UpdateLastScanText','UpdateEmptyState','UpdateList','UpdateSelectionText','UpdateActivityText','UpdateProgress','UpdateSelectAllButton','UpdateInstallButton','SecurityCenterButton','SecurityCenterNavDetail','SecurityCenterView','SecurityBackButton','SecurityRefreshButton','SecurityScoreBadge','SecurityScoreText','SecuritySummaryText','SecuritySummaryDetail','SecurityLastScanText','SecurityCheckList','OpenWindowsSecurityButton',
  'AppDetailOverlay','AppDetailBackdrop','AppDetailDrawer','AppDetailCloseButton','AppDetailLogo','AppDetailInitial','AppDetailName','AppDetailCategory','AppDetailStatusBadge','AppDetailStatusText','AppDetailStatusDescription','AppDetailInstalledVersion','AppDetailCatalogVersion','AppDetailMetadataState','AppDetailDescription','AppDetailId','AppDetailSource','AppDetailMetaCategory','AppDetailPublisher','AppDetailAuthor','AppDetailLicense','AppDetailInstallerType','AppDetailTags','AppDetailRepository','AppDetailHashStatus','AppDetailElevation','AppDetailCatalogUpdated','AppDetailRemoveButton','AppDetailWebsiteButton','AppDetailPrimaryButton','UninstallConfirmOverlay','UninstallConfirmBackdrop','UninstallConfirmAppName','UninstallConfirmDetail','UninstallCancelButton','UninstallConfirmButton','AboutButton','AboutOverlay','AboutBackdrop','AboutCard','AboutCloseButton','AboutByGogButton','AboutGitHubButton','SordumLink') | ForEach-Object {
    $controls[$_] = $window.FindName($_)
}

function New-ColorBrush([string]$color) {
    return [Windows.Media.BrushConverter]::new().ConvertFromString($color)
}

function New-ThemeGradientBrush([string[]]$Colors) {
    $brush = [Windows.Media.LinearGradientBrush]::new()
    $brush.StartPoint = [Windows.Point]::new(0, 0)
    $brush.EndPoint = [Windows.Point]::new(1, 1)
    $offsets = if ($Colors.Count -eq 2) { @(0.0, 1.0) } else { @(0.0, 0.58, 1.0) }
    for ($index = 0; $index -lt $Colors.Count; $index++) {
        $brush.GradientStops.Add([Windows.Media.GradientStop]::new(
            [Windows.Media.ColorConverter]::ConvertFromString($Colors[$index]),
            $offsets[[Math]::Min($index, $offsets.Count - 1)]
        ))
    }
    return $brush
}

function New-ThemeShadowEffect([string]$Color, [double]$BlurRadius, [double]$ShadowDepth, [double]$Opacity) {
    $effect = [Windows.Media.Effects.DropShadowEffect]::new()
    $effect.Color = [Windows.Media.ColorConverter]::ConvertFromString($Color)
    $effect.BlurRadius = $BlurRadius
    $effect.ShadowDepth = $ShadowDepth
    $effect.Opacity = $Opacity
    $effect.Direction = 270
    return $effect
}

$script:themeSettingsDirectory = Join-Path $env:LOCALAPPDATA 'PowerHub'
$script:themeSettingsPath = Join-Path $script:themeSettingsDirectory 'settings.json'
$script:themePreference = 'Auto'
$script:resolvedTheme = $null

function Get-WindowsApplicationTheme {
    try {
        $value = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme
        if ([int]$value -eq 1) { return 'Light' }
    } catch { }
    return 'Dark'
}

function Get-SavedThemePreference {
    if (-not (Test-Path -LiteralPath $script:themeSettingsPath)) { return 'Auto' }
    try {
        $settings = Get-Content -LiteralPath $script:themeSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]$settings.Theme -in @('Auto','Dark','Light')) { return [string]$settings.Theme }
    } catch { }
    return 'Auto'
}

function Save-ThemePreference([string]$Mode) {
    try {
        [IO.Directory]::CreateDirectory($script:themeSettingsDirectory) | Out-Null
        [pscustomobject]@{ Theme = $Mode } | ConvertTo-Json | Set-Content -LiteralPath $script:themeSettingsPath -Encoding UTF8
    } catch { }
}

function Set-ThemeButtonState([string]$Mode) {
    $icons = @{ Auto = [char]0xE790; Dark = [char]0xE708; Light = [char]0xE706 }
    $labels = @{ Auto = 'Otomatik'; Dark = 'Koyu'; Light = 'Açık' }
    $controls.ThemeButtonIcon.Text = [string]$icons[$Mode]
    $controls.ThemeButton.ToolTip = "Görünüm: $($labels[$Mode]) — değiştirmek için tıklayın"
    foreach ($button in @($controls.ThemeAutoButton,$controls.ThemeDarkButton,$controls.ThemeLightButton)) {
        $selected = ([string]$button.Tag -eq $Mode)
        $button.Background = if ($selected) { New-ColorBrush '#1A668C' } else { [Windows.Media.Brushes]::Transparent }
        $button.Foreground = if ($selected) { New-ColorBrush '#FFFFFF' } else { $window.FindResource('Ink') }
    }
}

function Set-PowerHubTheme {
    param([ValidateSet('Auto','Dark','Light')][string]$Mode = 'Auto', [switch]$Save)
    $resolved = if ($Mode -eq 'Auto') { Get-WindowsApplicationTheme } else { $Mode }
    $dark = ($resolved -eq 'Dark')
    $palette = if ($dark) {
        @{
            Primary='#38BDF8'; Ink='#F8FAFC'; Muted='#94A3B8'; SidebarBg='#0D141C'; Surface='#171E27';
            SurfaceRaised='#1C2530'; CardBg='#18212B'; CardBorder='#2D3A48'; SoftBg='#202C38'; SoftText='#BAE6FD';
            ActionBg='#222D38'; ActionHover='#263E49'; ActionBorder='#425366'; ActionIcon='#BAE6FD';
            DangerBg='#302126'; DangerBorder='#6B3338'; DangerIcon='#FF9B9B';
            SubtleBorder='#334252'; InputBg='#15202B'; OverlayBg='#E6080A0C'
        }
    } else {
        @{
            Primary='#0284C7'; Ink='#0F172A'; Muted='#526273'; SidebarBg='#F4F7FB'; Surface='#F8FAFC';
            SurfaceRaised='#FFFFFF'; CardBg='#FFFFFF'; CardBorder='#CBD5E1'; SoftBg='#E7EEF7'; SoftText='#075985';
            ActionBg='#DDEAF6'; ActionHover='#C8E0F2'; ActionBorder='#A9C0D5'; ActionIcon='#075985';
            DangerBg='#FFF0F1'; DangerBorder='#F2B7BC'; DangerIcon='#DC2626';
            SubtleBorder='#C7D2DF'; InputBg='#F8FAFC'; OverlayBg='#990F172A'
        }
    }
    $gradient = if ($dark) { @('#0B1118','#101923','#111827') } else { @('#F7FAFC','#EEF3F8','#E7EEF6') }
    $window.Resources['PageBg'] = New-ThemeGradientBrush -Colors $gradient
    foreach ($entry in $palette.GetEnumerator()) { $window.Resources[$entry.Key] = New-ColorBrush $entry.Value }
    $window.Resources['HeaderBg'] = New-ThemeGradientBrush -Colors $(if ($dark) { @('#1C2530','#18232F') } else { @('#FFFFFF','#F4F8FF') })
    $window.Resources['CardBg'] = if ($dark) { New-ColorBrush '#18212B' } else { New-ThemeGradientBrush -Colors @('#FFFFFF','#F8FBFF') }
    $window.Resources['CardShadow'] = if ($dark) {
        New-ThemeShadowEffect -Color '#020617' -BlurRadius 10 -ShadowDepth 2 -Opacity 0.16
    } else {
        New-ThemeShadowEffect -Color '#486580' -BlurRadius 14 -ShadowDepth 3 -Opacity 0.13
    }
    if ($controls.ThemeVisualLayer) {
        $visualAnimation = [Windows.Media.Animation.DoubleAnimation]::new()
        $visualAnimation.To = if ($dark) { 0.0 } else { 1.0 }
        $visualAnimation.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(260))
        $controls.ThemeVisualLayer.BeginAnimation([Windows.UIElement]::OpacityProperty, $visualAnimation)
    }
    if ($controls.WingetStatus) { $controls.WingetStatus.Foreground = $window.FindResource('Ink') }
    if ($controls.WingetDetail) { $controls.WingetDetail.Foreground = $window.FindResource('Muted') }
    if ($controls.UpdateCenterNavDetail) {
        $controls.UpdateCenterNavDetail.Foreground = New-ColorBrush $(if ($dark) { '#C8AC7F' } else { '#8A5A00' })
    }
    if ($controls.SecurityCenterNavDetail) {
        $controls.SecurityCenterNavDetail.Foreground = New-ColorBrush $(if ($dark) { '#86C9A8' } else { '#087451' })
    }
    $script:themePreference = $Mode
    $script:resolvedTheme = $resolved
    Set-ThemeButtonState -Mode $Mode
    if (Get-Command Update-CategoryThemeAppearance -ErrorAction SilentlyContinue) {
        $clearCategorySelection = ($controls.MainWorkspace.Visibility -ne [Windows.Visibility]::Visible)
        Update-CategoryThemeAppearance -ClearSelection:$clearCategorySelection
    }
    try {
        $handle = [Windows.Interop.WindowInteropHelper]::new($window).Handle
        [PowerHubWindowLayout]::ApplyDarkTitleBar($handle, $dark)
    } catch { }
    if ($Save) { Save-ThemePreference -Mode $Mode }
}

$controls.ThemePopup.PlacementTarget = $controls.ThemeButton
$controls.ThemeButton.Add_Click({ $controls.ThemePopup.IsOpen = -not $controls.ThemePopup.IsOpen })
foreach ($themeChoice in @($controls.ThemeAutoButton,$controls.ThemeDarkButton,$controls.ThemeLightButton)) {
    $themeChoice.Add_Click({
        param($sender,$eventArgs)
        Set-PowerHubTheme -Mode ([string]$sender.Tag) -Save
        $controls.ThemePopup.IsOpen = $false
    })
}
$script:themePreference = Get-SavedThemePreference
Set-PowerHubTheme -Mode $script:themePreference
$script:themeWatchTimer = [Windows.Threading.DispatcherTimer]::new()
$script:themeWatchTimer.Interval = [TimeSpan]::FromSeconds(2)
$script:themeWatchTimer.Add_Tick({
    if ($script:themePreference -eq 'Auto') {
        $current = Get-WindowsApplicationTheme
        if ($current -ne $script:resolvedTheme) { Set-PowerHubTheme -Mode 'Auto' }
    }
})
$script:themeWatchTimer.Start()

function Import-PowerHubBrandImage {
    param([string]$FileName = 'powerhub-logo.png')
    $candidates = @(
        (Join-Path $PSScriptRoot ("assets\{0}" -f $FileName)),
        (Join-Path $PSScriptRoot ("PowerHub\assets\{0}" -f $FileName))
    )
    $path = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $path) { return $null }
    $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
    $bitmap.BeginInit()
    $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.CreateOptions = [Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
    $bitmap.UriSource = [Uri]::new([IO.Path]::GetFullPath($path))
    $bitmap.EndInit()
    $bitmap.Freeze()
    return $bitmap
}

$brandImage = Import-PowerHubBrandImage -FileName 'powerhub-logo.png'
if ($brandImage) {
    $brandIcon = Import-PowerHubBrandImage -FileName 'powerhub-logo.ico'
    $window.Icon = if ($brandIcon) { $brandIcon } else { $brandImage }
}

$script:focusHistory = [Collections.Stack]::new()
$script:focusRegionIndex = -1

function Save-PowerHubFocus {
    $focused = [Windows.Input.Keyboard]::FocusedElement
    if ($focused) { $script:focusHistory.Push($focused) }
}

function Restore-PowerHubFocus {
    $focused = if ($script:focusHistory.Count -gt 0) { $script:focusHistory.Pop() } else { $null }
    if ($focused -and $focused.PSObject.Methods['Focus']) {
        $focused.Focus() | Out-Null
    } else {
        $controls.SearchBox.Focus() | Out-Null
    }
}

function Set-KeyboardHelpVisibility([bool]$Visible) {
    if ($Visible) {
        Save-PowerHubFocus
        $controls.KeyboardHelpOverlay.Visibility = [Windows.Visibility]::Visible
        $controls.KeyboardHelpCloseButton.Focus() | Out-Null
    } else {
        $controls.KeyboardHelpOverlay.Visibility = [Windows.Visibility]::Collapsed
        Restore-PowerHubFocus
    }
}

function Focus-PowerHubRegion([bool]$Reverse = $false) {
    $regions = [Collections.ArrayList]::new()
    $categoryButton = @($controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] -and $_.IsEnabled -and $_.Visibility -eq [Windows.Visibility]::Visible -and [string]$_.Tag -eq $script:activeCategory } | Select-Object -First 1)
    if ($categoryButton.Count -eq 0) { $categoryButton = @($controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] -and $_.IsEnabled -and $_.Visibility -eq [Windows.Visibility]::Visible } | Select-Object -First 1) }
    if ($categoryButton.Count -gt 0) { [void]$regions.Add($categoryButton[0]) }
    [void]$regions.Add($controls.SearchBox)
    if ($controls.AppList.Items.Count -gt 0) {
        if ($controls.AppList.SelectedIndex -lt 0) { $controls.AppList.SelectedIndex = 0 }
        $controls.AppList.UpdateLayout()
        $item = $controls.AppList.ItemContainerGenerator.ContainerFromIndex($controls.AppList.SelectedIndex)
        if ($item) { [void]$regions.Add($item) }
    }
    $action = @(@($controls.QueueViewButton,$controls.SelectAllButton,$controls.InstallButton) | Where-Object { $_.IsEnabled -and $_.Visibility -eq [Windows.Visibility]::Visible } | Select-Object -First 1)
    if ($action.Count -gt 0) { [void]$regions.Add($action[0]) }
    if ($regions.Count -eq 0) { return }
    $script:focusRegionIndex = if ($Reverse) {
        ($script:focusRegionIndex - 1 + $regions.Count) % $regions.Count
    } else {
        ($script:focusRegionIndex + 1) % $regions.Count
    }
    $regions[$script:focusRegionIndex].Focus() | Out-Null
}

function Send-PowerHubAnnouncement([string]$Message) {
    if ([string]::IsNullOrWhiteSpace($Message)) { return }
    [Windows.Automation.AutomationProperties]::SetName($controls.ActivityText,$Message)
    [Windows.Automation.AutomationProperties]::SetHelpText($controls.ActivityText,$Message)
    try {
        $peer = [Windows.Automation.Peers.UIElementAutomationPeer]::CreatePeerForElement($controls.ActivityText)
        if (-not $peer) { $peer = [Windows.Automation.Peers.FrameworkElementAutomationPeer]::new($controls.ActivityText) }
        $peer.RaiseAutomationEvent([Windows.Automation.Peers.AutomationEvents]::LiveRegionChanged)
    } catch { }
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
$uBlockOriginLogo = ConvertFrom-Base64Image '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'

$translateWebPagesLogo = ConvertFrom-Base64Image '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'
$greasyForkLogo = ConvertFrom-Base64Image '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'
$youtubeAutoHdLogo = ConvertFrom-Base64Image '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'
$firefoxRelayLogo = ConvertFrom-Base64Image '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'

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

function Import-PowerHubCatalog {
    $cacheDirectory = Join-Path $env:LOCALAPPDATA 'PowerHub'
    $cachePath = Join-Path $cacheDirectory 'catalog.json'
    $bundledPath = Join-Path $PSScriptRoot 'catalog.json'
    $developmentPath = Join-Path $PSScriptRoot 'PowerHub\catalog.json'
    $catalogPath = if (Test-Path -LiteralPath $bundledPath) {
        $bundledPath
    } elseif (Test-Path -LiteralPath $developmentPath) {
        $developmentPath
    } else {
        $null
    }

    try {
        if (-not $catalogPath) {
            [IO.Directory]::CreateDirectory($cacheDirectory) | Out-Null
            $response = Invoke-WebRequest -UseBasicParsing -Uri 'https://bygog.github.io/PowerHub/catalog.json' -TimeoutSec 20
            $json = if ($response.Content -is [byte[]]) {
                [Text.Encoding]::UTF8.GetString([byte[]]$response.Content)
            } else {
                [string]$response.Content
            }
            [IO.File]::WriteAllText($cachePath, $json, [Text.UTF8Encoding]::new($false))
            $catalogPath = $cachePath
        }

        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($catalog.SchemaVersion -ne 1) {
            throw "Desteklenmeyen katalog şeması: $($catalog.SchemaVersion)"
        }
        if (@($catalog.Applications).Count -eq 0 -or @($catalog.Categories).Count -eq 0) {
            throw 'Katalog uygulama veya kategori içermiyor.'
        }

        Write-PowerHubLog -Message "Katalog hazır: $(@($catalog.Applications).Count) uygulama, $(@($catalog.Categories).Count) kategori." -Color DarkCyan
        return $catalog
    } catch {
        throw "PowerHub kataloğu yüklenemedi: $($_.Exception.Message)"
    }
}

$catalog = Import-PowerHubCatalog
$apps = [Collections.ArrayList]::new()
foreach ($entry in @($catalog.Applications)) {
    $record = [ordered]@{}
    foreach ($property in $entry.PSObject.Properties) {
        $record[$property.Name] = $property.Value
    }
    $record['IsSelected'] = $false
    [void]$apps.Add([pscustomobject]$record)
}

$sevenZipApp = $apps | Where-Object Name -eq '7-Zip' | Select-Object -First 1
if ($sevenZipApp) {
    $sevenZipApp | Add-Member -NotePropertyName Logo -NotePropertyValue $sevenZipLogo -Force
    $sevenZipApp | Add-Member -NotePropertyName InitialOpacity -NotePropertyValue 0.0 -Force
}

$officialWebsiteCatalog = @{}
foreach ($property in $catalog.OfficialWebsites.PSObject.Properties) {
    $officialWebsiteCatalog[$property.Name] = [string]$property.Value
}

foreach ($app in $apps) {
    if (-not $app.PSObject.Properties['Logo']) {
        $app | Add-Member -NotePropertyName Logo -NotePropertyValue $null
    }
    if (-not $app.PSObject.Properties['InitialOpacity']) {
        $app | Add-Member -NotePropertyName InitialOpacity -NotePropertyValue 1.0
    }
    $isScriptAction = $app.PSObject.Properties['Action'] -and $app.Action -eq 'PowerShell'
    $isWebResource = $app.PSObject.Properties['Action'] -and $app.Action -in @('Url','PowerShell')
    $app | Add-Member -NotePropertyName IsScriptAction -NotePropertyValue $isScriptAction -Force
    $app | Add-Member -NotePropertyName IsWebResource -NotePropertyValue $isWebResource -Force
    $websiteUrl = if ($isWebResource) { $app.Url } else { $officialWebsiteCatalog[$app.Name] }
    $app | Add-Member -NotePropertyName WebsiteUrl -NotePropertyValue $websiteUrl -Force
    $app | Add-Member -NotePropertyName WebsiteVisibility -NotePropertyValue $(if ($websiteUrl) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }) -Force
    $app | Add-Member -NotePropertyName CheckVisibility -NotePropertyValue $(if ($isWebResource) { [Windows.Visibility]::Collapsed } else { [Windows.Visibility]::Visible }) -Force
    $app | Add-Member -NotePropertyName UninstallVisibility -NotePropertyValue ([Windows.Visibility]::Collapsed) -Force
    $app | Add-Member -NotePropertyName LinkVisibility -NotePropertyValue $(if ($isWebResource) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }) -Force
    if ($isWebResource) { $app.IsSelected = $false }
    $app | Add-Member -NotePropertyName InstallState -NotePropertyValue $(if ($isScriptAction) { 'Script' } elseif ($isWebResource) { 'Web' } else { 'Pending' }) -Force
    $app | Add-Member -NotePropertyName Operation -NotePropertyValue 'Install' -Force
    $app | Add-Member -NotePropertyName StatusDetail -NotePropertyValue $(if ($isScriptAction) { 'Kart tıklandığında PowerShell aracı çalıştırılır' } elseif ($isWebResource) { 'Resmî internet kaynağı' } else { 'Sistem durumu taranmayı bekliyor' }) -Force
    $app | Add-Member -NotePropertyName SourceLabel -NotePropertyValue $(if ($isScriptAction) { 'POWERSHELL' } elseif ($isWebResource) { 'SİTE' } else { 'BEKLİYOR' }) -Force
    $app | Add-Member -NotePropertyName SourceBackground -NotePropertyValue $(if ($isScriptAction) { '#174A42' } elseif ($isWebResource) { '#453C58' } else { '#263F52' }) -Force
    $app | Add-Member -NotePropertyName SourceForeground -NotePropertyValue $(if ($isScriptAction) { '#6EE7B7' } elseif ($isWebResource) { '#D8C7FF' } else { '#7DD3FC' }) -Force
    $app | Add-Member -NotePropertyName AccessibleName -NotePropertyValue ("{0}. {1}. {2}" -f $app.Name,$app.Description,$(if ($isScriptAction) { 'PowerShell komutu' } elseif ($isWebResource) { 'İnternet kaynağı' } else { 'Paket durumu taranıyor' })) -Force
}

$logoCatalog = Get-PowerHubLogoCatalog
foreach ($app in $apps) {
    $logoKey = if ($app.PSObject.Properties['LogoKey'] -and $app.LogoKey) { [string]$app.LogoKey } else { [string]$app.Name }
    if ($logoCatalog.ContainsKey($logoKey)) {
        try {
            $app.Logo = ConvertFrom-Base64Image $logoCatalog[$logoKey]
            $app.InitialOpacity = 0.0
        } catch {
            Write-PowerHubLog -Message "Logo okunamadı: $($app.Name)" -Color DarkYellow
        }
    }
}

# PowerShell 7 uses the current official PowerShell mark bundled with PowerHub.
# This local override also prevents an older cached logo catalog from restoring
# the legacy Windows-style icon.
$powerShellLogo = Import-PowerHubBrandImage -FileName 'powershell-logo.png'
if ($powerShellLogo) {
    $powerShellApp = $apps | Where-Object Name -eq 'PowerShell 7' | Select-Object -First 1
    if ($powerShellApp) {
        $powerShellApp.Logo = $powerShellLogo
        $powerShellApp.InitialOpacity = 0.0
    }
}

# The catalog version of the HWiNFO logo has opaque white corner pixels.
# Use the cleaned local asset so the rounded mark blends into dark cards.
$hwinfoLogo = Import-PowerHubBrandImage -FileName 'hwinfo-logo.png'
if ($hwinfoLogo) {
    $hwinfoApp = $apps | Where-Object Name -eq 'HWiNFO64' | Select-Object -First 1
    if ($hwinfoApp) {
        $hwinfoApp.Logo = $hwinfoLogo
        $hwinfoApp.InitialOpacity = 0.0
    }
}

# Prefer vendor-provided marks instead of stale or mismatched images from the
# downloadable logo catalog.
$vendorLogoOverrides = @{
    'CPU-Z'           = 'cpuz-logo.png'
    'GPU-Z'           = 'gpuz-logo.png'
    'OCCT'            = 'occt-logo.png'
    'PerformanceTest' = 'performancetest-logo.png'
    'BurnInTest'      = 'burnintest-logo.png'
    'FurMark 2'       = 'furmark-logo.png'
    'PowerToys'       = 'powertoys-logo.png'
    'TeraCopy'        = 'teracopy-logo.png'
    'O&O ShutUp10++'  = 'oosu10-logo.png'
    'VMware Workstation Pro' = 'vmware-workstation-logo.png'
    'Internet Download Manager' = 'internet-download-manager-logo.png'
    'Ninite'          = 'ninite-logo.png'
    'AtlasOS'         = 'atlasos-logo.png'
    'Softpedia'       = 'softpedia-logo.png'
    'TechSpot Downloads' = 'techspot-logo.png'
    'DNS Speed Test Online' = 'dns-speed-test-logo.png'
    'Win11Debloat'     = 'win11debloat-logo.png'
    'Bibata Modern Ice Cursor' = 'bibata-modern-ice-logo.png'
    'Yahoo Mail'        = 'yahoo-mail-logo.png'
    'Windows 10 Media Creation Tool' = 'media-creation-tool-logo.png'
    'Windows 11 Media Creation Tool' = 'media-creation-tool-logo.png'
}
foreach ($appName in $vendorLogoOverrides.Keys) {
    $vendorLogo = Import-PowerHubBrandImage -FileName $vendorLogoOverrides[$appName]
    if (-not $vendorLogo) { continue }
    $vendorApp = $apps | Where-Object Name -eq $appName | Select-Object -First 1
    if ($vendorApp) {
        $vendorApp.Logo = $vendorLogo
        $vendorApp.InitialOpacity = 0.0
    }
}

$categoryDefinitions = @($catalog.Categories)

foreach ($category in $categoryDefinitions) {
    $count = @($apps | Where-Object Category -eq $category.Name).Count
    $button = [Windows.Controls.Button]::new()
    $button.Style = $window.Resources['NavButton']
    $button.Tag = $category.Name
    $button.ToolTip = $category.Display
    $button.Margin = [Windows.Thickness]::new(0,1,0,1)
    $button.Padding = [Windows.Thickness]::new(9,7,7,7)
    [Windows.Automation.AutomationProperties]::SetName($button, "$($category.Display), $count uygulama")
    [Windows.Automation.AutomationProperties]::SetHelpText($button, 'Kategoriyi açmak için Enter veya Boşluk tuşuna basın')
    if ($category.Name -eq 'İnternet Tarayıcıları') {
        $button.Background = $window.FindResource('SoftBg')
        $button.BorderBrush = $window.FindResource('Primary')
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
    $icon.Foreground = $(if ($category.Name -eq 'İnternet Tarayıcıları') { $window.FindResource('Primary') } else { $window.FindResource('Muted') })
    $icon.FontSize = 15
    $icon.HorizontalAlignment = 'Left'
    $icon.VerticalAlignment = 'Center'

    $label = [Windows.Controls.TextBlock]::new()
    $label.Text = $category.Display
    $label.Foreground = $window.FindResource('Ink')
    $label.FontSize = 12
    $label.FontWeight = if ($category.Name -eq 'İnternet Tarayıcıları') { [Windows.FontWeights]::SemiBold } else { [Windows.FontWeights]::Normal }
    $label.VerticalAlignment = 'Center'
    $label.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
    [Windows.Controls.Grid]::SetColumn($label, 1)

    $countBadge = [Windows.Controls.Border]::new()
    $countBadge.Background = $window.FindResource('InputBg')
    $countBadge.BorderBrush = $window.FindResource('CardBorder')
    $countBadge.BorderThickness = [Windows.Thickness]::new(1)
    $countBadge.CornerRadius = [Windows.CornerRadius]::new(7)
    $countBadge.Padding = [Windows.Thickness]::new(6,3,6,3)
    $countBadge.MinWidth = 24
    $countBadge.VerticalAlignment = 'Center'
    $countBadge.HorizontalAlignment = 'Right'
    [Windows.Controls.Grid]::SetColumn($countBadge, 2)
    $countText = [Windows.Controls.TextBlock]::new()
    $countText.Text = [string]$count
    $countText.Foreground = $(if ($category.Name -eq 'İnternet Tarayıcıları') { $window.FindResource('Primary') } else { $window.FindResource('Muted') })
    $countText.FontSize = 10
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

$script:activeCategory = 'İnternet Tarayıcıları'
$script:isInstalling = $false
$script:visibleApps = @()
$script:updatePackages = [Collections.ObjectModel.ObservableCollection[object]]::new()
$script:updateScanCompleted = $false
$controls.UpdateList.ItemsSource = $script:updatePackages

function Update-CategoryThemeAppearance {
    param([switch]$ClearSelection)
    foreach ($nav in @($controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] })) {
        $isActive = (-not $ClearSelection -and [string]$nav.Tag -eq $script:activeCategory)
        $nav.Background = if ($isActive) { $window.FindResource('SoftBg') } else { [Windows.Media.Brushes]::Transparent }
        $nav.BorderBrush = if ($isActive) { $window.FindResource('Primary') } else { [Windows.Media.Brushes]::Transparent }
        $nav.BorderThickness = if ($isActive) { [Windows.Thickness]::new(3,0,0,0) } else { [Windows.Thickness]::new(0) }
        $nav.IconElement.Foreground = if ($isActive) { $window.FindResource('Primary') } else { $window.FindResource('Muted') }
        $nav.LabelElement.Foreground = if ($ClearSelection) { $window.FindResource('Muted') } else { $window.FindResource('Ink') }
        $nav.LabelElement.FontWeight = if ($isActive) { [Windows.FontWeights]::SemiBold } else { [Windows.FontWeights]::Normal }
        $nav.CountBadge.Background = $window.FindResource('InputBg')
        $nav.CountBadge.BorderBrush = $window.FindResource('CardBorder')
        $nav.CountElement.Foreground = if ($isActive) { $window.FindResource('Primary') } else { $window.FindResource('Muted') }
    }
}

Update-CategoryThemeAppearance

function ConvertFrom-WingetUpgradeOutput {
    param([AllowEmptyString()][string]$Output)

    if ([string]::IsNullOrWhiteSpace($Output)) { return @() }
    $ansiPattern = ([string][char]27) + '\[[0-9;?]*[ -/]*[@-~]'
    $cleanOutput = [Regex]::Replace($Output, $ansiPattern, '')
    $lines = @($cleanOutput -split "\r?\n")
    $separatorIndex = -1
    $headerIndex = -1
    $columnMatches = $null
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $matches = [Regex]::Matches($lines[$index], '-{3,}')
        if ($matches.Count -ge 4 -or $lines[$index] -match '^\s*-{8,}\s*$') {
            $separatorIndex = $index
            $columnMatches = $matches
            for ($candidate = $index - 1; $candidate -ge 0; $candidate--) {
                if (-not [string]::IsNullOrWhiteSpace($lines[$candidate])) {
                    $headerIndex = $candidate
                    break
                }
            }
            break
        }
    }
    if ($separatorIndex -lt 0) { return @() }

    $starts = @()
    if ($columnMatches.Count -ge 4) {
        $starts = @($columnMatches | ForEach-Object Index)
    } elseif ($headerIndex -ge 0) {
        $header = [string]$lines[$headerIndex]
        $idColumn = [Regex]::Match($header, '(?i)\b(?:Id|Kimlik)\b')
        $versionColumn = [Regex]::Match($header, '(?i)\b(?:Version|Sürüm)\b')
        $availableColumn = [Regex]::Match($header, '(?i)\b(?:Available|Kullanılabilir|Mevcut)\b')
        $sourceColumn = [Regex]::Match($header, '(?i)\b(?:Source|Kaynak)\b')
        if (-not ($idColumn.Success -and $versionColumn.Success -and $availableColumn.Success)) { return @() }
        $starts = @(0, $idColumn.Index, $versionColumn.Index, $availableColumn.Index)
        if ($sourceColumn.Success) { $starts += $sourceColumn.Index }
    }
    if ($starts.Count -lt 4) { return @() }
    $packages = [Collections.ArrayList]::new()
    for ($index = $separatorIndex + 1; $index -lt $lines.Count; $index++) {
        $line = [string]$lines[$index]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^\s*\d+\s+package' -or $line -match '^\s*No installed package') { break }
        if ($line.Length -le $starts[1]) { continue }

        $values = for ($column = 0; $column -lt $starts.Count; $column++) {
            $start = $starts[$column]
            if ($start -ge $line.Length) { ''; continue }
            $end = if ($column + 1 -lt $starts.Count) { [Math]::Min($line.Length, $starts[$column + 1]) } else { $line.Length }
            $line.Substring($start, [Math]::Max(0, $end - $start)).Trim()
        }
        if ($values.Count -lt 4) { continue }
        $name = [string]$values[0]
        $id = [string]$values[1]
        $current = [string]$values[2]
        $available = [string]$values[3]
        $source = if ($values.Count -ge 5 -and $values[4]) { [string]$values[4] } else { 'winget' }
        if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($available)) { continue }
        [void]$packages.Add([pscustomobject]@{
            Name = $name
            Id = $id
            CurrentVersion = $current
            AvailableVersion = $available
            Source = $source
            IsSelected = $false
        })
    }
    return @($packages)
}

function Update-UpdateCenterSelectionStatus {
    $selected = @($script:updatePackages | Where-Object IsSelected)
    $count = $script:updatePackages.Count
    $controls.UpdateCountText.Text = if ($count -eq 1) { '1 güncelleme' } else { "$count güncelleme" }
    $controls.UpdateCountBadge.Background = New-ColorBrush $(if ($count -gt 0) { '#574422' } else { '#123629' })
    $controls.UpdateCountBadge.BorderBrush = New-ColorBrush $(if ($count -gt 0) { '#7D632F' } else { '#236747' })
    $controls.UpdateCountText.Foreground = New-ColorBrush $(if ($count -gt 0) { '#FFD58A' } else { '#6EE7B7' })
    $controls.UpdateSelectionText.Text = if ($selected.Count -gt 0) { "$($selected.Count) paket güncellenecek" } elseif ($script:updateScanCompleted) { 'Henüz paket seçilmedi' } else { 'Güncelleme taraması bekleniyor' }
    if (-not $script:isInstalling) {
        $controls.UpdateActivityText.Text = if ($count -eq 0 -and $script:updateScanCompleted) { 'Sisteminizde bekleyen WinGet güncellemesi yok.' } elseif ($selected.Count -gt 0) { ($selected.Name -join ', ') } else { 'Güncellemek istediğiniz paketleri seçin.' }
    }
    $wingetReady = [bool](Resolve-WingetExecutable)
    $controls.UpdateSelectAllButton.IsEnabled = ($count -gt 0 -and -not $script:isInstalling)
    $controls.UpdateInstallButton.IsEnabled = ($selected.Count -gt 0 -and -not $script:isInstalling -and $wingetReady)
    $controls.UpdateSelectAllButton.Content = if ($count -gt 0 -and @($script:updatePackages | Where-Object { -not $_.IsSelected }).Count -eq 0) { 'Seçimi kaldır' } else { 'Tümünü seç' }
}

function Set-UpdateCenterPackages {
    param([AllowEmptyString()][string]$UpgradeOutput)

    $script:updatePackages.Clear()
    foreach ($package in @(ConvertFrom-WingetUpgradeOutput -Output $UpgradeOutput)) { $script:updatePackages.Add($package) }
    $script:updateScanCompleted = $true
    $controls.UpdateList.Visibility = if ($script:updatePackages.Count -gt 0) { 'Visible' } else { 'Collapsed' }
    $controls.UpdateEmptyState.Visibility = if ($script:updatePackages.Count -eq 0) { 'Visible' } else { 'Collapsed' }
    $controls.UpdateLastScanText.Text = "Son kontrol: $([DateTime]::Now.ToString('HH:mm:ss'))"
    $controls.UpdateCenterNavDetail.Text = if ($script:updatePackages.Count -gt 0) { "$($script:updatePackages.Count) güncelleme hazır" } else { 'Tüm paketler güncel' }
    Update-UpdateCenterSelectionStatus
}

function Set-UpdateCenterVisibility {
    param([bool]$Visible)
    $controls.UpdateCenterView.Visibility = if ($Visible) { 'Visible' } else { 'Collapsed' }
    if ($Visible) {
        $controls.SecurityCenterView.Visibility = 'Collapsed'
        $controls.FailureCenterView.Visibility = 'Collapsed'
    }
    $controls.MainWorkspace.Visibility = if ($Visible -or $controls.SecurityCenterView.Visibility -eq 'Visible' -or $controls.FailureCenterView.Visibility -eq 'Visible') { 'Collapsed' } else { 'Visible' }
    $controls.UpdateCenterButton.Background = if ($Visible) { New-ColorBrush '#202A35' } else { [Windows.Media.Brushes]::Transparent }
    $controls.UpdateCenterButton.BorderBrush = if ($Visible) { New-ColorBrush '#D09335' } else { [Windows.Media.Brushes]::Transparent }
    $controls.UpdateCenterButton.BorderThickness = if ($Visible) { [Windows.Thickness]::new(3,0,0,0) } else { [Windows.Thickness]::new(0) }
    if ($Visible) {
        $controls.SecurityCenterButton.Background = [Windows.Media.Brushes]::Transparent
        $controls.SecurityCenterButton.BorderBrush = [Windows.Media.Brushes]::Transparent
        $controls.SecurityCenterButton.BorderThickness = [Windows.Thickness]::new(0)
        $controls.FailureCenterButton.Background = [Windows.Media.Brushes]::Transparent
        $controls.FailureCenterButton.BorderBrush = [Windows.Media.Brushes]::Transparent
        $controls.FailureCenterButton.BorderThickness = [Windows.Thickness]::new(0)
        Update-CategoryThemeAppearance -ClearSelection
    }
    if ($Visible -and -not $script:updateScanCompleted -and -not $script:systemScanProcess) { Start-SystemScan }
}

$script:securityChecks = [Collections.ArrayList]::new()
$script:securityScanProcess = $null
$script:securityScanResultFile = $null
$script:securityScanCompleted = $false
$script:securityScanTimer = [Windows.Threading.DispatcherTimer]::new()
$script:securityScanTimer.Interval = [TimeSpan]::FromMilliseconds(350)

function New-SecurityCheckViewModel {
    param([string]$Name, [string]$Detail, [ValidateSet('Pass','Warning','Fail','Scanning')][string]$Status)
    $appearance = switch ($Status) {
        'Pass'     { @{ Icon='✓'; Label='GÜVENLİ'; Accent='#39C77A'; Background='#123629'; Border='#236747'; Foreground='#6EE7B7' } }
        'Warning'  { @{ Icon='!'; Label='DİKKAT'; Accent='#D09335'; Background='#574422'; Border='#7D632F'; Foreground='#FFD58A' } }
        'Fail'     { @{ Icon='×'; Label='RİSK'; Accent='#D85A63'; Background='#543136'; Border='#7D4449'; Foreground='#FFAAAA' } }
        default    { @{ Icon='…'; Label='DENETLENİYOR'; Accent='#38BDF8'; Background='#263F52'; Border='#36596E'; Foreground='#7DD3FC' } }
    }
    [pscustomobject]@{
        Name=$Name; Detail=$Detail; Status=$Status; Icon=$appearance.Icon; StatusLabel=$appearance.Label
        Accent=$appearance.Accent; IconBackground=$appearance.Background; StatusBackground=$appearance.Background
        StatusBorder=$appearance.Border; Foreground=$appearance.Foreground
    }
}

function Show-SecurityScanPlaceholder {
    $script:securityChecks.Clear()
    foreach ($name in @('Windows koruması','WinGet ve paket kaynakları','Yetki kapsamı','Betik çalıştırma ilkesi','Katalog bütünlüğü','Güncelleme durumu')) {
        [void]$script:securityChecks.Add((New-SecurityCheckViewModel -Name $name -Detail 'Denetim sürüyor...' -Status Scanning))
    }
    $controls.SecurityCheckList.ItemsSource = @($script:securityChecks)
    $controls.SecurityScoreText.Text = '…'
    $controls.SecuritySummaryText.Text = 'Güvenlik denetimi yapılıyor'
    $controls.SecuritySummaryDetail.Text = 'Windows ve PowerHub yapılandırması okunuyor.'
    $controls.SecurityScoreBadge.Background = New-ColorBrush '#263F52'
    $controls.SecurityScoreBadge.BorderBrush = New-ColorBrush '#36596E'
}

function Complete-SecurityScan {
    param($Result)
    $script:securityChecks.Clear()
    foreach ($check in @($Result.Checks)) {
        [void]$script:securityChecks.Add((New-SecurityCheckViewModel -Name ([string]$check.Name) -Detail ([string]$check.Detail) -Status ([string]$check.Status)))
    }

    $duplicateNames = @($apps | Group-Object Name | Where-Object Count -gt 1).Count
    $categoryNames = @($catalog.Categories | ForEach-Object Name)
    $invalidCategories = @($apps | Where-Object { $_.Category -notin $categoryNames }).Count
    $insecureWebResources = @($apps | Where-Object { $_.IsWebResource -and $_.Url -and $_.Url -notmatch '^https://' }).Count
    $insecureOfficialSites = @($catalog.OfficialWebsites.PSObject.Properties | Where-Object { [string]$_.Value -notmatch '^https://' }).Count
    $insecureLinks = $insecureWebResources + $insecureOfficialSites
    $catalogStatus = if ($duplicateNames -eq 0 -and $invalidCategories -eq 0 -and $insecureLinks -eq 0) { 'Pass' } else { 'Warning' }
    $catalogDetail = if ($catalogStatus -eq 'Pass') { "$($apps.Count) kayıt, $($categoryNames.Count) kategori ve HTTPS internet kaynakları doğrulandı." } else { "$duplicateNames yinelenen ad, $invalidCategories geçersiz kategori, $insecureLinks güvenli olmayan bağlantı." }
    [void]$script:securityChecks.Add((New-SecurityCheckViewModel -Name 'Katalog bütünlüğü' -Detail $catalogDetail -Status $catalogStatus))

    $updateCount = @($script:updatePackages).Count
    $updateStatus = if (-not $script:updateScanCompleted -or $updateCount -gt 0) { 'Warning' } else { 'Pass' }
    $updateDetail = if (-not $script:updateScanCompleted) { 'WinGet güncelleme taraması henüz tamamlanmadı.' } elseif ($updateCount -eq 0) { 'Taranan WinGet paketlerinde bekleyen güncelleme yok.' } else { "$updateCount paket için güncelleme bekliyor." }
    [void]$script:securityChecks.Add((New-SecurityCheckViewModel -Name 'Güncelleme durumu' -Detail $updateDetail -Status $updateStatus))

    $controls.SecurityCheckList.ItemsSource = $null
    $controls.SecurityCheckList.ItemsSource = @($script:securityChecks)
    $passCount = @($script:securityChecks | Where-Object Status -eq 'Pass').Count
    $warningCount = @($script:securityChecks | Where-Object Status -eq 'Warning').Count
    $failCount = @($script:securityChecks | Where-Object Status -eq 'Fail').Count
    $total = [Math]::Max(1, $script:securityChecks.Count)
    $score = [int][Math]::Round((($passCount * 100) + ($warningCount * 65)) / $total)
    $controls.SecurityScoreText.Text = "$score"
    $controls.SecurityLastScanText.Text = "Son denetim: $([DateTime]::Now.ToString('HH:mm:ss'))"
    $controls.SecurityCenterNavDetail.Text = if ($failCount -gt 0) { "$failCount risk bulundu" } elseif ($warningCount -gt 0) { "$warningCount uyarı var" } else { 'Koruma durumu iyi' }
    if ($failCount -gt 0) {
        $controls.SecuritySummaryText.Text = "$failCount güvenlik riski incelenmeli"
        $controls.SecuritySummaryDetail.Text = 'Kırmızı durumları gözden geçirip yeniden denetleyin.'
        $controls.SecurityScoreBadge.Background = New-ColorBrush '#543136'
        $controls.SecurityScoreBadge.BorderBrush = New-ColorBrush '#7D4449'
        $controls.SecurityScoreText.Foreground = New-ColorBrush '#FFAAAA'
    } elseif ($warningCount -gt 0) {
        $controls.SecuritySummaryText.Text = "Koruma etkin, $warningCount öneri mevcut"
        $controls.SecuritySummaryDetail.Text = 'Sistem kullanılabilir durumda; sarı maddeler iyileştirilebilir.'
        $controls.SecurityScoreBadge.Background = New-ColorBrush '#574422'
        $controls.SecurityScoreBadge.BorderBrush = New-ColorBrush '#7D632F'
        $controls.SecurityScoreText.Foreground = New-ColorBrush '#FFD58A'
    } else {
        $controls.SecuritySummaryText.Text = 'Tüm güvenlik denetimleri başarılı'
        $controls.SecuritySummaryDetail.Text = 'PowerHub ve Windows koruma katmanları beklenen durumda.'
        $controls.SecurityScoreBadge.Background = New-ColorBrush '#123629'
        $controls.SecurityScoreBadge.BorderBrush = New-ColorBrush '#236747'
        $controls.SecurityScoreText.Foreground = New-ColorBrush '#6EE7B7'
    }
    $script:securityScanCompleted = $true
    Write-PowerHubLog -Message "Güvenlik denetimi tamamlandı: $passCount güvenli, $warningCount uyarı, $failCount risk." -Color $(if ($failCount -gt 0) { 'Red' } elseif ($warningCount -gt 0) { 'Yellow' } else { 'Green' })
}

$script:securityScanTimer.Add_Tick({
    if (-not $script:securityScanProcess) { return }
    $script:securityScanProcess.Refresh()
    if (-not $script:securityScanProcess.HasExited) { return }
    $script:securityScanTimer.Stop()
    $script:securityScanProcess.Dispose()
    $script:securityScanProcess = $null
    try {
        if (-not $script:securityScanResultFile -or -not (Test-Path -LiteralPath $script:securityScanResultFile)) { throw 'Güvenlik denetimi sonucu oluşturulamadı.' }
        $result = Get-Content -LiteralPath $script:securityScanResultFile -Raw -Encoding UTF8 | ConvertFrom-Json
        Complete-SecurityScan -Result $result
    } catch {
        $controls.SecuritySummaryText.Text = 'Güvenlik denetimi tamamlanamadı'
        $controls.SecuritySummaryDetail.Text = $_.Exception.Message
        $controls.SecurityCenterNavDetail.Text = 'Denetim hatası'
        Write-PowerHubLog -Message "Güvenlik denetimi hatası: $($_.Exception.Message)" -Color Red
    } finally {
        $controls.SecurityRefreshButton.IsEnabled = $true
        if ($script:securityScanResultFile) { Remove-Item -LiteralPath $script:securityScanResultFile -Force -ErrorAction SilentlyContinue }
        $script:securityScanResultFile = $null
    }
})

function Start-SecurityScan {
    if ($script:securityScanProcess) { return }
    Show-SecurityScanPlaceholder
    $controls.SecurityRefreshButton.IsEnabled = $false
    $controls.SecurityLastScanText.Text = 'Denetleniyor...'
    Write-PowerHubLog -Message 'Güvenlik Merkezi denetimi başlatıldı.' -Color Cyan
    $script:securityScanResultFile = Join-Path $env:TEMP ("PowerHub-security-{0}.json" -f [Guid]::NewGuid().ToString('N'))
    $payload = @{ Winget=(Resolve-WingetExecutable); ResultFile=$script:securityScanResultFile } | ConvertTo-Json -Compress
    $payloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
    $worker = @'
$ErrorActionPreference = 'SilentlyContinue'
$payload = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__PAYLOAD__')) | ConvertFrom-Json
$checks = [Collections.ArrayList]::new()
function Add-Check([string]$Name,[string]$Detail,[string]$Status) { [void]$checks.Add([pscustomobject]@{Name=$Name;Detail=$Detail;Status=$Status}) }

$products = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue)
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($defender -and $defender.AntivirusEnabled -and $defender.RealTimeProtectionEnabled) {
    $age = if ($defender.AntivirusSignatureLastUpdated) { [int]((Get-Date) - [datetime]$defender.AntivirusSignatureLastUpdated).TotalDays } else { -1 }
    $status = if ($age -gt 7) { 'Warning' } else { 'Pass' }
    $detail = if ($age -ge 0) { "Microsoft Defender gerçek zamanlı koruması açık; imzalar $age günlük." } else { 'Microsoft Defender gerçek zamanlı koruması açık.' }
    Add-Check 'Windows koruması' $detail $status
} elseif ($products.Count -gt 0) {
    Add-Check 'Windows koruması' ("Kayıtlı güvenlik ürünü: " + (($products.DisplayName | Select-Object -Unique) -join ', ')) 'Warning'
} else {
    Add-Check 'Windows koruması' 'Etkin bir antivirüs veya gerçek zamanlı koruma algılanamadı.' 'Fail'
}

if ($payload.Winget) {
    $version = (& $payload.Winget --version 2>&1 | Out-String).Trim()
    $sourceOutput = (& $payload.Winget source list 2>&1 | Out-String)
    $sourceOk = $LASTEXITCODE -eq 0 -and $sourceOutput -match '(?im)^winget\s+'
    Add-Check 'WinGet ve paket kaynakları' $(if ($sourceOk) { "WinGet $version hazır; resmî winget kaynağı etkin." } else { "WinGet $version hazır ancak kaynak listesi doğrulanamadı." }) $(if ($sourceOk) { 'Pass' } else { 'Warning' })
} else {
    Add-Check 'WinGet ve paket kaynakları' 'WinGet bulunamadı; paket doğrulama ve kurulum motoru kullanılamıyor.' 'Fail'
}

$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Add-Check 'Yetki kapsamı' $(if ($isAdmin) { 'PowerHub yönetici yetkisiyle çalışıyor; yalnızca gerektiğinde yükseltilmiş oturum kullanın.' } else { 'PowerHub standart kullanıcı yetkisiyle çalışıyor.' }) $(if ($isAdmin) { 'Warning' } else { 'Pass' })

$policies = Get-ExecutionPolicy -List
$persistentUnsafe = @($policies | Where-Object { $_.Scope -in @('CurrentUser','LocalMachine') -and $_.ExecutionPolicy -in @('Bypass','Unrestricted') })
Add-Check 'Betik çalıştırma ilkesi' $(if ($persistentUnsafe.Count -eq 0) { 'Kalıcı kullanıcı ve makine ilkelerinde sınırsız ya da atlatılmış çalışma izni bulunmuyor.' } else { 'Kalıcı betik çalıştırma ilkesi gevşetilmiş: ' + (($persistentUnsafe | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" }) -join ', ') }) $(if ($persistentUnsafe.Count -eq 0) { 'Pass' } else { 'Warning' })

Add-Check 'Kurulum güvenliği' 'Tam paket kimliği, exact eşleşme ve WinGet kaynak kısıtlaması kullanılıyor.' 'Pass'
[IO.File]::WriteAllText($payload.ResultFile, (@{Checks=@($checks)} | ConvertTo-Json -Depth 5 -Compress), [Text.UTF8Encoding]::new($false))
'@.Replace('__PAYLOAD__',$payloadBase64)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($worker))
    try {
        $script:securityScanProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -WindowStyle Hidden -PassThru
        $script:securityScanTimer.Start()
    } catch {
        $controls.SecurityRefreshButton.IsEnabled = $true
        Write-PowerHubLog -Message "Güvenlik denetimi başlatılamadı: $($_.Exception.Message)" -Color Red
    }
}

function Set-SecurityCenterVisibility {
    param([bool]$Visible)
    $controls.SecurityCenterView.Visibility = if ($Visible) { 'Visible' } else { 'Collapsed' }
    if ($Visible) {
        $controls.UpdateCenterView.Visibility = 'Collapsed'
        $controls.FailureCenterView.Visibility = 'Collapsed'
    }
    $controls.MainWorkspace.Visibility = if ($Visible -or $controls.UpdateCenterView.Visibility -eq 'Visible' -or $controls.FailureCenterView.Visibility -eq 'Visible') { 'Collapsed' } else { 'Visible' }
    $controls.SecurityCenterButton.Background = if ($Visible) { New-ColorBrush '#202A35' } else { [Windows.Media.Brushes]::Transparent }
    $controls.SecurityCenterButton.BorderBrush = if ($Visible) { New-ColorBrush '#39C77A' } else { [Windows.Media.Brushes]::Transparent }
    $controls.SecurityCenterButton.BorderThickness = if ($Visible) { [Windows.Thickness]::new(3,0,0,0) } else { [Windows.Thickness]::new(0) }
    if ($Visible) {
        $controls.UpdateCenterButton.Background = [Windows.Media.Brushes]::Transparent
        $controls.UpdateCenterButton.BorderBrush = [Windows.Media.Brushes]::Transparent
        $controls.UpdateCenterButton.BorderThickness = [Windows.Thickness]::new(0)
        $controls.FailureCenterButton.Background = [Windows.Media.Brushes]::Transparent
        $controls.FailureCenterButton.BorderBrush = [Windows.Media.Brushes]::Transparent
        $controls.FailureCenterButton.BorderThickness = [Windows.Thickness]::new(0)
        Update-CategoryThemeAppearance -ClearSelection
        if (-not $script:securityScanCompleted) { Start-SecurityScan }
    }
}

function Update-SelectionStatus {
    $previousSelectionText = [string]$controls.SelectionText.Text
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
    if ($previousSelectionText -ne [string]$controls.SelectionText.Text) { Send-PowerHubAnnouncement $controls.SelectionText.Text }
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
    $controls.SelectAllButton.ToolTip = if ($hasInstallableApps) { 'Görünen kurulabilir uygulamaları seç veya seçimi kaldır (Ctrl+A)' } else { 'Site kartına tıklayarak resmî sayfayı açın' }
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
            $App.SourceForeground = '#7DD3FC'
            $App.StatusDetail = 'Sistemde kurulu olup olmadığı denetleniyor'
            $App.Operation = 'None'
            $App.IsSelected = $false
            $App.CheckVisibility = [Windows.Visibility]::Collapsed
            $App.UninstallVisibility = [Windows.Visibility]::Collapsed
        }
        'NotInstalled' {
            $App.SourceLabel = 'KURULU DEĞİL'
            $App.SourceBackground = '#263F52'
            $App.SourceForeground = '#7DD3FC'
            $App.StatusDetail = 'Bu uygulama bilgisayarda kurulu değil'
            $App.Operation = 'Install'
            $App.CheckVisibility = [Windows.Visibility]::Visible
            $App.UninstallVisibility = [Windows.Visibility]::Collapsed
        }
        'Installed' {
            $App.SourceLabel = 'KURULU'
            $App.SourceBackground = '#123B2C'
            $App.SourceForeground = '#6EE7B7'
            $App.StatusDetail = 'Uygulama kurulu ve güncel'
            $App.Operation = 'None'
            $App.IsSelected = $false
            $App.CheckVisibility = [Windows.Visibility]::Collapsed
            $App.UninstallVisibility = [Windows.Visibility]::Visible
        }
        'UpdateAvailable' {
            $App.SourceLabel = 'GÜNCELLEME'
            $App.SourceBackground = '#574422'
            $App.SourceForeground = '#FFD58A'
            $App.StatusDetail = 'Yeni sürüm mevcut; seçerek güncelleyebilirsiniz'
            $App.Operation = 'Upgrade'
            $App.CheckVisibility = [Windows.Visibility]::Visible
            $App.UninstallVisibility = [Windows.Visibility]::Visible
        }
        'Unknown' {
            $App.SourceLabel = 'DURUM YOK'
            $App.SourceBackground = '#3A3F45'
            $App.SourceForeground = '#B9C2C9'
            $App.StatusDetail = 'Kurulum durumu belirlenemedi; uygulama yine de kurulabilir'
            $App.Operation = 'Install'
            $App.CheckVisibility = [Windows.Visibility]::Visible
            $App.UninstallVisibility = [Windows.Visibility]::Collapsed
        }
    }
    $App.AccessibleName = "{0}. {1}. {2}" -f $App.Name,$App.Description,$App.StatusDetail
}

$customAddonLogos = @{
    'uBlock Origin' = $uBlockOriginLogo
    'TWP Translate Web Pages' = $translateWebPagesLogo
    'Greasy Fork' = $greasyForkLogo
    'YouTube Auto HD + FPS' = $youtubeAutoHdLogo
    'Firefox Relay' = $firefoxRelayLogo
}
foreach ($logoEntry in $customAddonLogos.GetEnumerator()) {
    $logoApp = $apps | Where-Object Name -eq $logoEntry.Key | Select-Object -First 1
    if ($logoApp) {
        $logoApp.Logo = $logoEntry.Value
        $logoApp.InitialOpacity = 0.0
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
    $updateCount = $script:updatePackages.Count
    $controls.SystemScanBadge.Background = New-ColorBrush $(if ($updateCount -gt 0) { '#574422' } else { '#123629' })
    $controls.SystemScanBadgeText.Foreground = New-ColorBrush $(if ($updateCount -gt 0) { '#FFD58A' } else { '#6EE7B7' })
    $controls.SystemScanBadgeText.Text = if ($updateCount -gt 0) { "●  $installedCount kurulu • $updateCount yeni" } else { "●  $installedCount kurulu" }
    $controls.SystemScanBadge.ToolTip = if ($updateCount -gt 0) { "$updateCount uygulama için güncelleme var" } else { 'Taranan uygulamalar güncel' }
    Send-PowerHubAnnouncement ("Sistem taraması tamamlandı. {0} uygulama kurulu, {1} güncelleme mevcut." -f $installedCount,$updateCount)
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
    Set-UpdateCenterPackages -UpgradeOutput $upgradeOutput
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
    $updateCount = $script:updatePackages.Count
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
        $controls.UpdateRefreshButton.IsEnabled = $true
    } catch {
        foreach ($app in @($apps | Where-Object { -not $_.IsWebResource })) { Set-AppInstallState -App $app -State Unknown }
        Update-AppList
        Update-SelectionStatus
        $controls.SystemScanBadge.Background = New-ColorBrush '#543136'
        $controls.SystemScanBadgeText.Foreground = New-ColorBrush '#FFAAAA'
        $controls.SystemScanBadgeText.Text = '●  Tarama başarısız'
        $controls.SystemScanBadge.ToolTip = $_.Exception.Message
        $controls.ActivityText.Text = 'Sistem taraması tamamlanamadı; uygulamalar yine de kurulabilir.'
        $controls.UpdateCountText.Text = 'Tarama hatası'
        $controls.UpdateLastScanText.Text = 'WinGet güncelleme listesi alınamadı'
        $controls.UpdateActivityText.Text = $_.Exception.Message
        $controls.UpdateRefreshButton.IsEnabled = $true
        Write-PowerHubLog -Message "Akıllı tarama hatası: $($_.Exception.Message)" -Color Red
    } finally {
        if ($script:systemScanResultFile) { Remove-Item -LiteralPath $script:systemScanResultFile -Force -ErrorAction SilentlyContinue }
        $script:systemScanResultFile = $null
    }
})

function Start-SystemScan {
    param([switch]$PreserveCurrentState)
    if ($script:systemScanProcess -or $script:isInstalling) { return }
    $winget = Resolve-WingetExecutable
    if (-not $winget) { return }

    if (-not $PreserveCurrentState) {
        foreach ($app in @($apps | Where-Object { -not $_.IsWebResource })) { Set-AppInstallState -App $app -State Pending }
        Update-AppList
        Update-SelectionStatus
    }
    $controls.SelectAllButton.IsEnabled = $false
    $controls.SystemScanBadge.Background = New-ColorBrush '#263F52'
    $controls.SystemScanBadgeText.Foreground = New-ColorBrush '#7DD3FC'
    $controls.SystemScanBadgeText.Text = '◌  Sistem taranıyor'
    $controls.SystemScanBadge.ToolTip = 'Kurulu uygulamalar ve güncellemeler denetleniyor'
    if (-not $PreserveCurrentState) { $controls.ActivityText.Text = 'Kurulu uygulamalar ve güncellemeler taranıyor...' }
    $controls.UpdateCountText.Text = 'Taranıyor'
    $controls.UpdateLastScanText.Text = 'WinGet paketleri denetleniyor...'
    $controls.UpdateEmptyState.Visibility = 'Collapsed'
    $controls.UpdateList.Visibility = 'Visible'
    $controls.UpdateRefreshButton.IsEnabled = $false
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
    $result.UpgradeOutput = (& $payload.Winget list --upgrade-available --include-unknown --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
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
        $controls.UpdateRefreshButton.IsEnabled = $true
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
    Set-UpdateCenterVisibility $false
    Set-SecurityCenterVisibility $false
    Set-FailureCenterVisibility $false
    Update-CategoryThemeAppearance
    $targetButton = @($controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] -and [string]$_.Tag -eq $CategoryName } | Select-Object -First 1)
    if ($targetButton) {
        $targetButton[0].BringIntoView()
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

function Invoke-WingetSearchInTerminal {
    param([string]$Query)

    $queryText = $Query.Trim()
    if ([string]::IsNullOrWhiteSpace($queryText)) { return }

    try {
        $winget = Resolve-WingetExecutable
        if (-not $winget) { throw 'winget çalıştırılabilir dosyası bulunamadı.' }

        # Encode the command instead of concatenating user input into -Command.
        # This keeps spaces, quotes and non-ASCII package names safe.
        $safeWinget = $winget.Replace("'", "''")
        $safeQuery = $queryText.Replace("'", "''")
        $terminalCommand = @"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
`$host.UI.RawUI.WindowTitle = 'PowerHub - WinGet araması'
Write-Host ''
Write-Host 'PowerHub WinGet araması' -ForegroundColor Cyan
Write-Host 'Sorgu: $safeQuery' -ForegroundColor Gray
Write-Host ''
& '$safeWinget' search --query '$safeQuery'
Write-Host ''
if (`$LASTEXITCODE -ne 0) {
    Write-Host "WinGet araması tamamlanamadı (kod: `$LASTEXITCODE)." -ForegroundColor Red
} else {
    Write-Host 'Arama tamamlandı.' -ForegroundColor Green
    Write-Host 'Kurmak istediğiniz uygulamanın Kimlik (Id) değerini tablodan kopyalayın.' -ForegroundColor Gray
    Write-Host 'Ardından şu komutu yazın:' -ForegroundColor Gray
    Write-Host 'winget install --id PAKET.KIMLIGI -e' -ForegroundColor Cyan
    Write-Host 'Örnek: winget install --id 7zip.7zip -e' -ForegroundColor DarkGray
}
"@
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($terminalCommand))
        Start-Process -FilePath 'powershell.exe' -ArgumentList @(
            '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encodedCommand
        ) | Out-Null

        $controls.ActivityText.Text = "WinGet araması terminalde açıldı: $queryText"
        Write-PowerHubLog -Message "Katalog dışı WinGet araması açıldı: $queryText" -Color Cyan
        Send-PowerHubAnnouncement "WinGet araması terminalde açıldı: $queryText"
    } catch {
        $message = "WinGet araması açılamadı: $($_.Exception.Message)"
        $controls.ActivityText.Text = $message
        Write-PowerHubLog -Message $message -Color Red
        Send-PowerHubAnnouncement $message
    }
}

$controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] } | ForEach-Object {
    $button = $_
    $button.Add_Click({
        param($sender, $eventArgs)
        Set-ActiveCategory -CategoryName ([string]$sender.Tag)
        Update-AppList
    })
}

$controls.UpdateCenterButton.Add_Click({ Set-UpdateCenterVisibility $true })
$controls.UpdateBackButton.Add_Click({
    Set-ActiveCategory -CategoryName $script:activeCategory
    Update-AppList
})
$controls.UpdateRefreshButton.Add_Click({ Start-SystemScan })
$controls.SecurityCenterButton.Add_Click({ Set-SecurityCenterVisibility $true })
$controls.SecurityBackButton.Add_Click({
    Set-ActiveCategory -CategoryName $script:activeCategory
    Update-AppList
})
$controls.SecurityRefreshButton.Add_Click({ Start-SecurityScan })
$controls.OpenWindowsSecurityButton.Add_Click({
    try { Start-Process -FilePath 'windowsdefender:' } catch { Write-PowerHubLog -Message "Windows Güvenliği açılamadı: $($_.Exception.Message)" -Color Red }
})
$controls.FailureCenterButton.Add_Click({ Set-FailureCenterVisibility $true })
$controls.FailureBackButton.Add_Click({
    Set-ActiveCategory -CategoryName $script:activeCategory
    Update-AppList
})
$controls.FailureClearButton.Add_Click({
    if ($script:isInstalling) { return }
    $script:failedOperations.Clear()
    Save-FailedOperations
    Update-FailureCenterSummary
})
$failureActionHandler = [Windows.RoutedEventHandler]{
    param($sender, $eventArgs)
    $button = $eventArgs.Source -as [Windows.Controls.Button]
    if (-not $button) {
        $node = $eventArgs.OriginalSource
        while ($node -and -not ($node -is [Windows.Controls.Button])) {
            try { $node = [Windows.Media.VisualTreeHelper]::GetParent($node) } catch { $node = $null }
        }
        $button = $node -as [Windows.Controls.Button]
    }
    if (-not $button -or -not $button.DataContext) { return }
    $failure = $button.DataContext
    switch ($button.Name) {
        'FailureWebsiteButton' {
            if ($failure.HasWebsite) {
                try { Start-Process -FilePath $failure.Website } catch { Write-PowerHubLog -Message "Resmî site açılamadı: $($_.Exception.Message)" -Color Red }
            }
        }
        'FailureInteractiveButton' {
            if ($script:isInstalling -or $failure.Operation -eq 'OpenUrl') { return }
            try {
                $winget = Resolve-WingetExecutable
                if (-not $winget) { throw 'winget çalıştırılabilir dosyası bulunamadı.' }
                $entry = Convert-FailureToQueueEntry -Failure $failure
                $arguments = @(Get-PackageOperationArguments -Item $entry -Interactive)
                $argumentText = ($arguments | ForEach-Object { "'" + ([string]$_).Replace("'","''") + "'" }) -join ' '
                $command = "& '" + $winget.Replace("'","''") + "' " + $argumentText
                Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-Command',$command)
                Write-PowerHubLog -Message "Etkileşimli işlem açıldı: $($failure.Name)" -Color Yellow
            } catch {
                Write-PowerHubLog -Message "Etkileşimli işlem açılamadı ($($failure.Name)): $($_.Exception.Message)" -Color Red
            }
        }
        'FailureRetryButton' {
            if ($script:isInstalling) { return }
            if ($failure.Operation -eq 'OpenUrl') {
                if ($failure.HasWebsite) {
                    try {
                        Start-Process -FilePath $failure.Website
                        Resolve-FailedOperation -Id $failure.Id -Operation OpenUrl
                    } catch { Write-PowerHubLog -Message "Site yeniden açılamadı: $($_.Exception.Message)" -Color Red }
                }
                return
            }
            $entry = Convert-FailureToQueueEntry -Failure $failure
            Initialize-InstallQueue -Entries @($entry)
            Set-FailureCenterVisibility $false
            Start-InstallQueueExecution
        }
    }
    $eventArgs.Handled = $true
}
$controls.FailureList.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, $failureActionHandler, $true)
$controls.UpdateList.AddHandler([Windows.Controls.CheckBox]::CheckedEvent, [Windows.RoutedEventHandler]{ Update-UpdateCenterSelectionStatus })
$controls.UpdateList.AddHandler([Windows.Controls.CheckBox]::UncheckedEvent, [Windows.RoutedEventHandler]{ Update-UpdateCenterSelectionStatus })
$controls.UpdateSelectAllButton.Add_Click({
    $allSelected = $script:updatePackages.Count -gt 0 -and @($script:updatePackages | Where-Object { -not $_.IsSelected }).Count -eq 0
    foreach ($package in $script:updatePackages) { $package.IsSelected = -not $allSelected }
    $controls.UpdateList.Items.Refresh()
    Update-UpdateCenterSelectionStatus
})

$controls.SearchBox.Add_TextChanged({
    Update-SearchChrome
    $searchCategory = Find-BestSearchCategory -Query $controls.SearchBox.Text.Trim()
    if ($searchCategory) { Set-ActiveCategory -CategoryName $searchCategory }
    Update-AppList
})
$controls.SearchBox.Add_KeyDown({
    param($sender, $eventArgs)

    if ($eventArgs.Key -ne [Windows.Input.Key]::Enter) { return }
    $query = $controls.SearchBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($query)) { return }

    Invoke-WingetSearchInTerminal -Query $query
    $eventArgs.Handled = $true
})
$controls.SearchClearButton.Add_Click({
    $controls.SearchBox.Clear()
    $controls.SearchBox.Focus() | Out-Null
})
$controls.KeyboardHelpButton.Add_Click({ Set-KeyboardHelpVisibility $true })
$controls.KeyboardHelpCloseButton.Add_Click({ Set-KeyboardHelpVisibility $false })
$controls.KeyboardHelpBackdrop.Add_MouseLeftButtonUp({ Set-KeyboardHelpVisibility $false })
function Set-PowerHubAboutVisibility([bool]$Visible) {
    $wasVisible = $controls.AboutOverlay.Visibility -eq [Windows.Visibility]::Visible
    if ($Visible -and -not $wasVisible) { Save-PowerHubFocus }
    $controls.AboutOverlay.Visibility = if ($Visible) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    if ($Visible) { $controls.AboutCloseButton.Focus() | Out-Null }
    elseif ($wasVisible) { Restore-PowerHubFocus }
}
$controls.AboutButton.Add_Click({ Set-PowerHubAboutVisibility $true })
$controls.AboutCloseButton.Add_Click({ Set-PowerHubAboutVisibility $false })
$controls.AboutBackdrop.Add_MouseLeftButtonUp({ Set-PowerHubAboutVisibility $false })
$controls.AboutByGogButton.Add_Click({
    try { Start-Process -FilePath 'https://bygog.github.io/' } catch { Write-PowerHubLog -Message "byGOG internet sitesi açılamadı: $($_.Exception.Message)" -Color Red }
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

function Invoke-PowerHubCatalogCommand {
    param($Item)
    if (-not $Item -or -not $Item.IsScriptAction -or -not $Item.PSObject.Properties['Command'] -or [string]::IsNullOrWhiteSpace([string]$Item.Command)) { return }
    try {
        $command = [string]$Item.Command
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        Start-Process -FilePath 'powershell.exe' -ArgumentList @(
            '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-EncodedCommand',$encodedCommand
        ) | Out-Null
        $controls.ActivityText.Text = "PowerShell aracı başlatıldı: $($Item.Name)"
        Write-PowerHubLog -Message "PowerShell komutu çalıştırıldı: $($Item.Name) — $command" -Color Cyan
    } catch {
        $controls.ActivityText.Text = "PowerShell aracı başlatılamadı: $($Item.Name)"
        Write-PowerHubLog -Message "PowerShell komutu başlatılamadı ($($Item.Name)): $($_.Exception.Message)" -Color Red
    }
}

$script:detailApp = $null
$script:detailMetadataProcess = $null
$script:detailMetadataResultFile = $null
$script:detailMetadataCache = @{}
$script:detailMetadataTimer = [Windows.Threading.DispatcherTimer]::new()
$script:detailMetadataTimer.Interval = [TimeSpan]::FromMilliseconds(250)

function Stop-AppDetailMetadataLoad {
    $script:detailMetadataTimer.Stop()
    if ($script:detailMetadataProcess) {
        try {
            $script:detailMetadataProcess.Refresh()
            if (-not $script:detailMetadataProcess.HasExited) { Stop-Process -Id $script:detailMetadataProcess.Id -Force -ErrorAction SilentlyContinue }
            $script:detailMetadataProcess.Dispose()
        } catch {}
        $script:detailMetadataProcess = $null
    }
    if ($script:detailMetadataResultFile) {
        Remove-Item -LiteralPath $script:detailMetadataResultFile -Force -ErrorAction SilentlyContinue
        $script:detailMetadataResultFile = $null
    }
}

function Get-AppDetailWingetField {
    param([string]$Output, [string[]]$Labels)
    foreach ($label in $Labels) {
        $match = [Regex]::Match($Output, ('(?im)^\s*' + [Regex]::Escape($label) + '\s*:\s*(.+?)\s*$'))
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    return '—'
}

function Get-AppDetailInstalledVersion {
    param([string]$Output, [string]$Id)
    foreach ($line in @($Output -split "\r?\n")) {
        $match = [Regex]::Match($line, ('(?i)(?:^|\s)' + [Regex]::Escape($Id) + '\s+(\S+)'))
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    return '—'
}

function Get-AppDetailTags {
    param([string]$Output)
    $lines = @($Output -split "\r?\n")
    $start = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\s*(Tags|Etiketler)\s*:\s*$') { $start = $index + 1; break }
    }
    if ($start -lt 0) { return '—' }
    $tags = @()
    for ($index = $start; $index -lt $lines.Count; $index++) {
        $value = $lines[$index].Trim()
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        if ($value -match '^[^:]+:\s*') { break }
        $tags += $value
        if ($tags.Count -ge 8) { break }
    }
    return $(if ($tags.Count -gt 0) { $tags -join '  •  ' } else { '—' })
}

function Get-AppDetailRepository {
    param([string]$Output)
    foreach ($label in @('Publisher Url','Publisher URL','Homepage','Release Notes Url','Release Notes URL')) {
        $value = Get-AppDetailWingetField -Output $Output -Labels @($label)
        if ($value -ne '—' -and $value -match '(?i)^https://github\.com/[^/\s]+/[^/#?\s]+') {
            return $matches[0].TrimEnd('.git')
        }
    }
    return 'Belirtilmemiş'
}

function Get-AppDetailElevation {
    param([string]$Output)
    $value = Get-AppDetailWingetField -Output $Output -Labels @('Elevation Requirement','Yükseltme Gereksinimi','Install Scope','Installation Scope','Scope','Kapsam')
    if ($value -eq '—') { return 'Kurucuya bağlı' }
    if ($value -match '(?i)elevat|admin|machine') { return 'Yönetici yetkisi gerekebilir' }
    if ($value -match '(?i)user|kullanıcı') { return 'Kullanıcı kapsamı' }
    return $value
}

function Get-PowerHubCatalogDate {
    $value = [string]$catalog.UpdatedAt
    if ([string]::IsNullOrWhiteSpace($value)) { return 'Belirtilmemiş' }
    try { return ([DateTime]::Parse($value)).ToString('dd.MM.yyyy') } catch { return $value }
}

function Set-AppDetailMetadata {
    param($Metadata)
    $installedVersion = $Metadata.InstalledVersion
    if ($script:detailApp -and $script:detailApp.InstallState -notin @('Installed','UpdateAvailable') -and $installedVersion -eq '—') { $installedVersion = 'Kurulu değil' }
    $controls.AppDetailInstalledVersion.Text = $installedVersion
    $controls.AppDetailCatalogVersion.Text = $Metadata.CatalogVersion
    $controls.AppDetailPublisher.Text = $Metadata.Publisher
    $controls.AppDetailAuthor.Text = $Metadata.Author
    $controls.AppDetailLicense.Text = $Metadata.License
    $controls.AppDetailInstallerType.Text = $Metadata.InstallerType
    $controls.AppDetailTags.Text = $Metadata.Tags
    $controls.AppDetailRepository.Text = $Metadata.Repository
    $controls.AppDetailRepository.ToolTip = $Metadata.Repository
    $controls.AppDetailHashStatus.Text = $Metadata.HashStatus
    $controls.AppDetailHashStatus.ToolTip = $Metadata.Hash
    $controls.AppDetailElevation.Text = $Metadata.Elevation
    $controls.AppDetailCatalogUpdated.Text = $Metadata.CatalogUpdated
    $controls.AppDetailMetadataState.Text = $Metadata.State
}

$script:detailMetadataTimer.Add_Tick({
    if (-not $script:detailMetadataProcess) { return }
    $script:detailMetadataProcess.Refresh()
    if (-not $script:detailMetadataProcess.HasExited) { return }
    $script:detailMetadataTimer.Stop()
    $script:detailMetadataProcess.WaitForExit()
    $script:detailMetadataProcess.Dispose()
    $script:detailMetadataProcess = $null
    try {
        if (-not $script:detailMetadataResultFile -or -not (Test-Path -LiteralPath $script:detailMetadataResultFile)) { throw 'Paket ayrıntısı alınamadı.' }
        $result = Get-Content -LiteralPath $script:detailMetadataResultFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $hash = Get-AppDetailWingetField -Output ([string]$result.ShowOutput) -Labels @('Installer SHA256','Installer SHA-256','Kurucu SHA256')
        $hashStatus = if ($hash -eq '—') { 'Manifestte belirtilmemiş' } else {
            $shortHash = if ($hash.Length -gt 24) { '{0}…{1}' -f $hash.Substring(0,12).ToUpperInvariant(),$hash.Substring($hash.Length-8).ToUpperInvariant() } else { $hash.ToUpperInvariant() }
            "WinGet kurulumda doğrular • $shortHash"
        }
        $metadata = [pscustomobject]@{
            InstalledVersion = Get-AppDetailInstalledVersion -Output ([string]$result.ListOutput) -Id ([string]$result.Id)
            CatalogVersion = Get-AppDetailWingetField -Output ([string]$result.ShowOutput) -Labels @('Version','Sürüm')
            Publisher = Get-AppDetailWingetField -Output ([string]$result.ShowOutput) -Labels @('Publisher','Yayıncı')
            Author = Get-AppDetailWingetField -Output ([string]$result.ShowOutput) -Labels @('Author','Geliştirici')
            License = Get-AppDetailWingetField -Output ([string]$result.ShowOutput) -Labels @('License','Lisans')
            InstallerType = Get-AppDetailWingetField -Output ([string]$result.ShowOutput) -Labels @('Installer Type','Kurucu Türü')
            Tags = Get-AppDetailTags -Output ([string]$result.ShowOutput)
            Repository = Get-AppDetailRepository -Output ([string]$result.ShowOutput)
            Hash = $hash
            HashStatus = $hashStatus
            Elevation = Get-AppDetailElevation -Output ([string]$result.ShowOutput)
            CatalogUpdated = Get-PowerHubCatalogDate
            State = if ([int]$result.ShowExitCode -eq 0) { "WinGet ayrıntıları hazır • $([DateTime]::Now.ToString('HH:mm:ss'))" } else { 'Katalog ayrıntılarının bir bölümü alınamadı' }
        }
        $script:detailMetadataCache[[string]$result.Id] = $metadata
        if ($script:detailApp -and $script:detailApp.Id -eq [string]$result.Id) { Set-AppDetailMetadata -Metadata $metadata }
    } catch {
        if ($script:detailApp) { $controls.AppDetailMetadataState.Text = 'WinGet ayrıntıları alınamadı; temel bilgiler kullanılabilir.' }
    } finally {
        if ($script:detailMetadataResultFile) { Remove-Item -LiteralPath $script:detailMetadataResultFile -Force -ErrorAction SilentlyContinue }
        $script:detailMetadataResultFile = $null
    }
})

function Start-AppDetailMetadataLoad {
    param($App)
    Stop-AppDetailMetadataLoad
    if ($App.IsWebResource) {
        Set-AppDetailMetadata -Metadata ([pscustomobject]@{
            InstalledVersion='Gerekmez'; CatalogVersion='Çevrim içi'; Publisher='Resmî internet kaynağı'; Author='—'; License='Siteye göre'; InstallerType='İnternet bağlantısı'; Tags='İnternet  •  Kaynak'; Repository=$(if ($App.WebsiteUrl) { $App.WebsiteUrl } else { 'Belirtilmemiş' }); Hash='—'; HashStatus='Uygulanamaz'; Elevation='Yetki gerekmez'; CatalogUpdated=(Get-PowerHubCatalogDate); State='İnternet kaynağı • kurulum gerektirmez'
        })
        return
    }
    if ($script:detailMetadataCache.ContainsKey($App.Id)) {
        Set-AppDetailMetadata -Metadata $script:detailMetadataCache[$App.Id]
        return
    }
    Set-AppDetailMetadata -Metadata ([pscustomobject]@{
        InstalledVersion='…'; CatalogVersion='…'; Publisher='Yükleniyor'; Author='Yükleniyor'; License='Yükleniyor'; InstallerType='Yükleniyor'; Tags='Yükleniyor'; Repository='Yükleniyor'; Hash=''; HashStatus='Denetleniyor'; Elevation='Denetleniyor'; CatalogUpdated=(Get-PowerHubCatalogDate); State='WinGet katalog ayrıntıları alınıyor...'
    })
    $source = 'winget'
    if ($App.PSObject.Properties['InstallArguments']) {
        $arguments = @($App.InstallArguments)
        $sourceIndex = [Array]::IndexOf([object[]]$arguments, '--source')
        if ($sourceIndex -ge 0 -and ($sourceIndex + 1) -lt $arguments.Count) { $source = [string]$arguments[$sourceIndex + 1] }
    }
    $controls.AppDetailSource.Text = if ($source -eq 'msstore') { 'Microsoft Mağazası' } else { 'WinGet topluluk kaynağı' }
    $script:detailMetadataResultFile = Join-Path $env:TEMP ("PowerHub-detail-{0}.json" -f [Guid]::NewGuid().ToString('N'))
    $payloadJson = @{ Winget=(Resolve-WingetExecutable); Id=$App.Id; Source=$source; ResultFile=$script:detailMetadataResultFile } | ConvertTo-Json -Compress
    $payloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payloadJson))
    $worker = @'
$ErrorActionPreference = 'SilentlyContinue'
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$payload = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__PAYLOAD__')) | ConvertFrom-Json
$result = [ordered]@{ Id=$payload.Id; ListOutput=''; ShowOutput=''; ListExitCode=1; ShowExitCode=1 }
$result.ListOutput = (& $payload.Winget list --id $payload.Id --exact --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
$result.ListExitCode = [int]$LASTEXITCODE
$result.ShowOutput = (& $payload.Winget show --id $payload.Id --exact --source $payload.Source --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
$result.ShowExitCode = [int]$LASTEXITCODE
if ($result.ShowExitCode -ne 0) {
    $result.ShowOutput = (& $payload.Winget show --id $payload.Id --exact --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
    $result.ShowExitCode = [int]$LASTEXITCODE
}
[IO.File]::WriteAllText($payload.ResultFile, ($result | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
'@.Replace('__PAYLOAD__', $payloadBase64)
    try {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($worker))
        $script:detailMetadataProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -WindowStyle Hidden -PassThru
        $script:detailMetadataTimer.Start()
    } catch {
        $controls.AppDetailMetadataState.Text = 'WinGet ayrıntıları başlatılamadı.'
        Stop-AppDetailMetadataLoad
    }
}
function Close-AppDetail {
    $wasVisible = $controls.AppDetailOverlay.Visibility -eq [Windows.Visibility]::Visible
    Stop-AppDetailMetadataLoad
    $controls.AppDetailOverlay.Visibility = [Windows.Visibility]::Collapsed
    $script:detailApp = $null
    if ($wasVisible) { Restore-PowerHubFocus }
}

function Show-AppDetail {
    param($App)
    if (-not $App) { return }
    if ($controls.AppDetailOverlay.Visibility -ne [Windows.Visibility]::Visible) { Save-PowerHubFocus }
    $script:detailApp = $App
    $controls.AppDetailName.Text = $App.Name
    $controls.AppDetailCategory.Text = $App.Category
    $controls.AppDetailDescription.Text = $App.Description
    $controls.AppDetailId.Text = if ($App.IsWebResource) { 'İnternet kaynağı' } else { $App.Id }
    $controls.AppDetailSource.Text = if ($App.IsWebResource) { 'Resmî internet kaynağı' } else { 'WinGet' }
    $controls.AppDetailMetaCategory.Text = $App.Category
    $controls.AppDetailLogo.Source = $App.Logo
    $controls.AppDetailInitial.Text = $App.Initial
    $controls.AppDetailInitial.Foreground = New-ColorBrush $App.Color
    $controls.AppDetailInitial.Opacity = $App.InitialOpacity
    $controls.AppDetailStatusText.Text = $App.SourceLabel
    $controls.AppDetailStatusDescription.Text = $App.StatusDetail
    $controls.AppDetailStatusText.Foreground = New-ColorBrush $App.SourceForeground
    $controls.AppDetailStatusBadge.Background = New-ColorBrush $App.SourceBackground
    $controls.AppDetailStatusBadge.BorderBrush = New-ColorBrush $App.SourceBackground
    $controls.AppDetailWebsiteButton.Visibility = if ($App.WebsiteUrl) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $controls.AppDetailRemoveButton.Visibility = if ($App.InstallState -in @('Installed','UpdateAvailable')) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $controls.AppDetailPrimaryButton.IsEnabled = -not $script:isInstalling
    $controls.AppDetailPrimaryButton.Visibility = [Windows.Visibility]::Visible
    if ($App.IsScriptAction) {
        $controls.AppDetailPrimaryButton.Content = 'Aracı çalıştır  →'
    } elseif ($App.IsWebResource) {
        $controls.AppDetailPrimaryButton.Content = 'Siteyi aç  →'
        $controls.AppDetailWebsiteButton.Visibility = [Windows.Visibility]::Collapsed
    } elseif ($App.InstallState -eq 'Installed') {
        $controls.AppDetailPrimaryButton.Visibility = [Windows.Visibility]::Collapsed
    } elseif ($App.InstallState -eq 'UpdateAvailable') {
        $controls.AppDetailPrimaryButton.Content = 'Güncelleme için seç  →'
    } elseif ($App.InstallState -eq 'Pending') {
        $controls.AppDetailPrimaryButton.Content = 'Durum taranıyor'
        $controls.AppDetailPrimaryButton.IsEnabled = $false
    } else {
        $controls.AppDetailPrimaryButton.Content = 'Kurulum için seç  →'
    }
    Start-AppDetailMetadataLoad -App $App
    $controls.AppDetailOverlay.Visibility = [Windows.Visibility]::Visible
    $translate = [Windows.Media.TranslateTransform]::new(24,0)
    $controls.AppDetailDrawer.RenderTransform = $translate
    $controls.AppDetailDrawer.Opacity = 0
    $duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(180))
    $controls.AppDetailDrawer.BeginAnimation([Windows.UIElement]::OpacityProperty, [Windows.Media.Animation.DoubleAnimation]::new(0,1,$duration))
    $translate.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, [Windows.Media.Animation.DoubleAnimation]::new(24,0,$duration))
    $controls.AppDetailCloseButton.Focus() | Out-Null
}

$controls.AppDetailCloseButton.Add_Click({ Close-AppDetail })
$controls.AppDetailBackdrop.Add_MouseLeftButtonUp({ Close-AppDetail })
$controls.AppDetailWebsiteButton.Add_Click({
    if ($script:detailApp) { Open-PowerHubWebsite -Item $script:detailApp -Url $script:detailApp.WebsiteUrl -WebResource:$script:detailApp.IsWebResource }
})
$controls.AppDetailPrimaryButton.Add_Click({
    $app = $script:detailApp
    if (-not $app) { return }
    if ($app.IsScriptAction) {
        Invoke-PowerHubCatalogCommand -Item $app
    } elseif ($app.IsWebResource) {
        Open-PowerHubWebsite -Item $app -Url $app.Url -WebResource
    } elseif ($app.Operation -ne 'None') {
        $app.IsSelected = $true
        Update-AppList
        Update-SelectionStatus
    }
    Close-AppDetail
})
$controls.AppDetailRemoveButton.Add_Click({
    $app = $script:detailApp
    Close-AppDetail
    if ($app) { Request-AppUninstall -App $app }
})

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
    if (-not $button) { return }
    if ($button.Name -eq 'DetailButton') {
        Show-AppDetail -App $button.DataContext
        $eventArgs.Handled = $true
        return
    }
    if ($button.Name -eq 'UninstallButton') {
        Request-AppUninstall -App $button.DataContext
        $eventArgs.Handled = $true
        return
    }
    if ([string]::IsNullOrWhiteSpace([string]$button.Tag)) { return }
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
            if ($node.Name -in @('DetailButton','UninstallButton')) { return }
            Open-PowerHubWebsite -Item $item -Url ([string]$node.Tag) -WebResource:$item.IsWebResource
            $eventArgs.Handled = $true
            return
        }
        if ($node -is [Windows.Controls.CheckBox]) { return }
        try { $node = [Windows.Media.VisualTreeHelper]::GetParent($node) } catch { $node = $null }
    }

    if ($item.IsScriptAction) {
        Invoke-PowerHubCatalogCommand -Item $item
        $eventArgs.Handled = $true
        return
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

    $controlDown = ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0
    $shiftDown = ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift) -ne 0

    if ($eventArgs.Key -eq [Windows.Input.Key]::F1) {
        $isVisible = $controls.KeyboardHelpOverlay.Visibility -eq [Windows.Visibility]::Visible
        Set-KeyboardHelpVisibility (-not $isVisible)
        $eventArgs.Handled = $true
        return
    }
    if ($eventArgs.Key -eq [Windows.Input.Key]::Escape -and $controls.KeyboardHelpOverlay.Visibility -eq [Windows.Visibility]::Visible) {
        Set-KeyboardHelpVisibility $false
        $eventArgs.Handled = $true
        return
    }
    if ($eventArgs.Key -eq [Windows.Input.Key]::Escape -and $controls.UninstallConfirmOverlay.Visibility -eq [Windows.Visibility]::Visible) {
        Close-UninstallConfirmation
        $eventArgs.Handled = $true
        return
    }
    if ($eventArgs.Key -eq [Windows.Input.Key]::Escape -and $controls.AppDetailOverlay.Visibility -eq [Windows.Visibility]::Visible) {
        Close-AppDetail
        $eventArgs.Handled = $true
        return
    }
    if ($eventArgs.Key -eq [Windows.Input.Key]::Escape -and $controls.InstallQueueOverlay.Visibility -eq [Windows.Visibility]::Visible) {
        Set-InstallQueueVisibility $false
        $eventArgs.Handled = $true
        return
    }
    if ($eventArgs.Key -eq [Windows.Input.Key]::Escape -and $controls.AboutOverlay.Visibility -eq [Windows.Visibility]::Visible) {
        Set-PowerHubAboutVisibility $false
        $eventArgs.Handled = $true
        return
    }
    if ($eventArgs.Key -eq [Windows.Input.Key]::Escape -and ($controls.SecurityCenterView.Visibility -eq [Windows.Visibility]::Visible -or $controls.UpdateCenterView.Visibility -eq [Windows.Visibility]::Visible -or $controls.FailureCenterView.Visibility -eq [Windows.Visibility]::Visible)) {
        Set-ActiveCategory -CategoryName $script:activeCategory
        Update-AppList
        $eventArgs.Handled = $true
        return
    }
    $modalVisible = @(@($controls.KeyboardHelpOverlay,$controls.UninstallConfirmOverlay,$controls.AppDetailOverlay,$controls.InstallQueueOverlay,$controls.AboutOverlay) | Where-Object { $_.Visibility -eq [Windows.Visibility]::Visible }).Count -gt 0
    if ($modalVisible) { return }
    if ($eventArgs.Key -eq [Windows.Input.Key]::F6) {
        Focus-PowerHubRegion -Reverse:$shiftDown
        $eventArgs.Handled = $true
        return
    }
    if ($controlDown -and $eventArgs.Key -in @([Windows.Input.Key]::F,[Windows.Input.Key]::K)) {
        $controls.SearchBox.Focus() | Out-Null
        $controls.SearchBox.SelectAll()
        $eventArgs.Handled = $true
        return
    }
    if ($eventArgs.Key -eq [Windows.Input.Key]::F5) {
        if ($controls.SecurityCenterView.Visibility -eq [Windows.Visibility]::Visible) { Start-SecurityScan } else { Start-SystemScan }
        $eventArgs.Handled = $true
        return
    }
    if ($controlDown -and $eventArgs.Key -eq [Windows.Input.Key]::Q -and $script:installQueueItems.Count -gt 0) {
        Set-InstallQueueVisibility $true
        $controls.QueueCloseButton.Focus() | Out-Null
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

    $focusedElement = [Windows.Input.Keyboard]::FocusedElement
    $focusIsActionControl = $focusedElement -is [Windows.Controls.Button] -or $focusedElement -is [Windows.Controls.CheckBox]
    if ($controls.AppList.IsKeyboardFocusWithin -and -not $focusIsActionControl -and $controls.AppList.SelectedItem) {
        $focusedApp = $controls.AppList.SelectedItem
        if ($eventArgs.Key -eq [Windows.Input.Key]::Space) {
            if ($focusedApp.IsScriptAction) {
                Invoke-PowerHubCatalogCommand -Item $focusedApp
            } elseif ($focusedApp.IsWebResource) {
                Open-PowerHubWebsite -Item $focusedApp -Url $focusedApp.Url -WebResource
            } elseif ($focusedApp.Operation -ne 'None') {
                $focusedApp.IsSelected = -not [bool]$focusedApp.IsSelected
                $controls.AppList.Items.Refresh()
                Update-SelectionStatus
            }
            $eventArgs.Handled = $true
            return
        }
        if ($eventArgs.Key -eq [Windows.Input.Key]::Enter) {
            Show-AppDetail -App $focusedApp
            $controls.AppDetailCloseButton.Focus() | Out-Null
            $eventArgs.Handled = $true
            return
        }
    }
    if ($controlDown -and $eventArgs.Key -eq [Windows.Input.Key]::Enter -and $controls.InstallButton.IsEnabled) {
        $controls.InstallButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        $eventArgs.Handled = $true
        return
    }
})

$controls.SelectAllButton.Add_Click({
    $installableApps = @($script:visibleApps | Where-Object { -not $_.IsWebResource -and $_.Operation -ne 'None' })
    $allSelected = $installableApps.Count -gt 0 -and @($installableApps | Where-Object { -not $_.IsSelected }).Count -eq 0
    foreach ($app in $installableApps) { $app.IsSelected = -not $allSelected }
    Update-AppList
    Update-SelectionStatus
})

$script:failureHistoryPath = Join-Path (Join-Path $env:LOCALAPPDATA 'PowerHub') 'failed-operations.json'
$script:failedOperations = [Collections.ObjectModel.ObservableCollection[object]]::new()
$controls.FailureList.ItemsSource = $script:failedOperations

function Get-AppOfficialWebsite {
    param([string]$Name, [string]$Fallback)
    if (-not [string]::IsNullOrWhiteSpace($Fallback)) { return $Fallback }
    if ($catalog.OfficialWebsites -and $catalog.OfficialWebsites.PSObject.Properties[$Name]) {
        return [string]$catalog.OfficialWebsites.PSObject.Properties[$Name].Value
    }
    return ''
}

function Save-FailedOperations {
    try {
        $directory = Split-Path -Parent $script:failureHistoryPath
        if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
        $payload = @($script:failedOperations | Select-Object Name,Id,Operation,OperationLabel,Code,CodeLabel,Detail,Time,TimeText,Website,HasWebsite,CanInteractive,Action,InstallArguments,PackageSource)
        $json = if ($payload.Count -eq 0) { '[]' } else { $payload | ConvertTo-Json -Depth 6 }
        [IO.File]::WriteAllText($script:failureHistoryPath, $json, [Text.UTF8Encoding]::new($false))
    } catch {
        Write-PowerHubLog -Message "Başarısız işlem geçmişi kaydedilemedi: $($_.Exception.Message)" -Color DarkYellow
    }
}

function Update-FailureCenterSummary {
    $count = $script:failedOperations.Count
    $controls.FailureCountText.Text = "$count başarısız"
    $controls.FailureCenterNavDetail.Text = if ($count -gt 0) { "$count işlem incelenmeli" } else { 'Kayıt bulunmuyor' }
    $controls.FailureEmptyState.Visibility = if ($count -eq 0) { 'Visible' } else { 'Collapsed' }
    $controls.FailureList.Visibility = if ($count -gt 0) { 'Visible' } else { 'Collapsed' }
    $controls.FailureClearButton.IsEnabled = ($count -gt 0)
    $controls.FailureFooterTitle.Text = if ($count -gt 0) { "$count işlem yeniden denenebilir" } else { 'Hata geçmişi temiz' }
    $controls.FailureLastText.Text = if ($count -gt 0) { "Son hata: $($script:failedOperations[0].TimeText)" } else { 'Henüz başarısız işlem yok' }
}

function Add-FailedOperation {
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][ValidateSet('Install','Upgrade','Uninstall','OpenUrl')][string]$Operation,
        [int]$Code,
        [string]$Detail,
        [object[]]$Arguments
    )
    $name = [string]$Item.Name
    $id = if ($Item.PSObject.Properties['Id']) { [string]$Item.Id } else { '' }
    $existing = $script:failedOperations | Where-Object { $_.Id -eq $id -and $_.Operation -eq $Operation } | Select-Object -First 1
    if ($existing) { [void]$script:failedOperations.Remove($existing) }
    $websiteFallback = if ($Item.PSObject.Properties['Url']) { [string]$Item.Url } else { '' }
    $website = Get-AppOfficialWebsite -Name $name -Fallback $websiteFallback
    $operationLabel = switch ($Operation) { 'Install' {'Kurulum'} 'Upgrade' {'Güncelleme'} 'Uninstall' {'Kaldırma'} default {'İnternet sayfası'} }
    $time = [DateTime]::Now
    $entry = [pscustomobject]@{
        Name = $name
        Id = $id
        Operation = $Operation
        OperationLabel = $operationLabel
        Code = $Code
        CodeLabel = if ($Code -eq -1) { 'BAŞLATMA HATASI' } else { "KOD $Code" }
        Detail = if ([string]::IsNullOrWhiteSpace($Detail)) { 'WinGet işlemi tamamlanamadı' } else { $Detail }
        Time = $time.ToString('o')
        TimeText = $time.ToString('dd.MM.yyyy HH:mm')
        Website = $website
        HasWebsite = -not [string]::IsNullOrWhiteSpace($website)
        CanInteractive = ($Operation -ne 'OpenUrl')
        Action = if ($Item.PSObject.Properties['Action']) { [string]$Item.Action } else { 'Winget' }
        InstallArguments = if ($Arguments) { @($Arguments) } elseif ($Item.PSObject.Properties['InstallArguments']) { @($Item.InstallArguments) } else { @() }
        PackageSource = if ($Item.PSObject.Properties['PackageSource'] -and $Item.PackageSource) { [string]$Item.PackageSource } elseif ($Item.PSObject.Properties['Source'] -and $Item.Source) { [string]$Item.Source } else { 'winget' }
    }
    $script:failedOperations.Insert(0, $entry)
    while ($script:failedOperations.Count -gt 50) { $script:failedOperations.RemoveAt($script:failedOperations.Count - 1) }
    Save-FailedOperations
    Update-FailureCenterSummary
}

function Resolve-FailedOperation {
    param([string]$Id, [string]$Operation)
    $matches = @($script:failedOperations | Where-Object { $_.Id -eq $Id -and $_.Operation -eq $Operation })
    foreach ($match in $matches) { [void]$script:failedOperations.Remove($match) }
    if ($matches.Count -gt 0) {
        Save-FailedOperations
        Update-FailureCenterSummary
    }
}

function Import-FailedOperations {
    if (-not (Test-Path -LiteralPath $script:failureHistoryPath)) { Update-FailureCenterSummary; return }
    try {
        $records = @(Get-Content -LiteralPath $script:failureHistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json)
        foreach ($record in $records | Select-Object -First 50) {
            if (-not $record.Name) { continue }
            $record | Add-Member -NotePropertyName HasWebsite -NotePropertyValue (-not [string]::IsNullOrWhiteSpace([string]$record.Website)) -Force
            $record | Add-Member -NotePropertyName CanInteractive -NotePropertyValue ($record.Operation -ne 'OpenUrl') -Force
            [void]$script:failedOperations.Add($record)
        }
    } catch {
        Write-PowerHubLog -Message "Başarısız işlem geçmişi okunamadı: $($_.Exception.Message)" -Color DarkYellow
    }
    Update-FailureCenterSummary
}

function Set-FailureCenterVisibility {
    param([bool]$Visible)
    $controls.FailureCenterView.Visibility = if ($Visible) { 'Visible' } else { 'Collapsed' }
    if ($Visible) {
        $controls.UpdateCenterView.Visibility = 'Collapsed'
        $controls.SecurityCenterView.Visibility = 'Collapsed'
    }
    $otherVisible = $controls.UpdateCenterView.Visibility -eq 'Visible' -or $controls.SecurityCenterView.Visibility -eq 'Visible'
    $controls.MainWorkspace.Visibility = if ($Visible -or $otherVisible) { 'Collapsed' } else { 'Visible' }
    $controls.FailureCenterButton.Background = if ($Visible) { New-ColorBrush '#202A35' } else { [Windows.Media.Brushes]::Transparent }
    $controls.FailureCenterButton.BorderBrush = if ($Visible) { New-ColorBrush '#E0525C' } else { [Windows.Media.Brushes]::Transparent }
    $controls.FailureCenterButton.BorderThickness = if ($Visible) { [Windows.Thickness]::new(3,0,0,0) } else { [Windows.Thickness]::new(0) }
    if ($Visible) {
        foreach ($button in @($controls.UpdateCenterButton,$controls.SecurityCenterButton)) {
            $button.Background = [Windows.Media.Brushes]::Transparent
            $button.BorderBrush = [Windows.Media.Brushes]::Transparent
            $button.BorderThickness = [Windows.Thickness]::new(0)
        }
        Update-CategoryThemeAppearance -ClearSelection
    }
}

$script:updateQueue = @()
$script:updateIndex = 0
$script:updateResults = [Collections.ArrayList]::new()
$script:updateProcess = $null
$script:updateTimer = [Windows.Threading.DispatcherTimer]::new()
$script:updateTimer.Interval = [TimeSpan]::FromMilliseconds(400)

function Complete-UpdateQueue {
    $script:updateTimer.Stop()
    $script:isInstalling = $false
    $controls.UpdateProgress.Value = 100
    $controls.UpdateRefreshButton.IsEnabled = $true
    $failed = @($script:updateResults | Where-Object { -not $_.Success })
    $successCount = @($script:updateResults | Where-Object Success).Count
    $controls.UpdateSelectionText.Text = "Güncelleme işlemi tamamlandı"
    $controls.UpdateActivityText.Text = if ($failed.Count -eq 0) { "$successCount paket başarıyla güncellendi." } else { "$successCount başarılı, $($failed.Count) başarısız." }
    Write-PowerHubLog -Message "Güncelleme Merkezi tamamlandı: $successCount başarılı, $($failed.Count) başarısız." -Color $(if ($failed.Count -eq 0) { 'Green' } else { 'Yellow' })
    foreach ($package in $script:updatePackages) { $package.IsSelected = $false }
    $controls.UpdateList.Items.Refresh()
    Update-UpdateCenterSelectionStatus
    Start-SystemScan -PreserveCurrentState
}

function Start-NextUpdate {
    if ($script:updateIndex -ge $script:updateQueue.Count) {
        Complete-UpdateQueue
        return
    }

    $package = $script:updateQueue[$script:updateIndex]
    $controls.UpdateProgress.Value = [int](($script:updateIndex / $script:updateQueue.Count) * 100)
    $controls.UpdateSelectionText.Text = "Güncelleniyor: $($package.Name)"
    $controls.UpdateActivityText.Text = "$($package.CurrentVersion) → $($package.AvailableVersion)"
    $arguments = @('upgrade','--id',$package.Id,'--exact')
    if (-not [string]::IsNullOrWhiteSpace($package.Source)) { $arguments += @('--source',$package.Source) }
    $arguments += @('--include-unknown','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')

    try {
        $winget = Resolve-WingetExecutable
        if (-not $winget) { throw 'winget çalıştırılabilir dosyası bulunamadı.' }
        Write-PowerHubLog -Message "Güncelleniyor: $($package.Name) ($($package.Id))" -Color Cyan
        Write-PowerHubLog -Message "Komut: winget $($arguments -join ' ')" -Color DarkGray
        $script:updateProcess = Start-Process -FilePath $winget -ArgumentList $arguments -PassThru -NoNewWindow
        $script:updateTimer.Start()
    } catch {
        Write-PowerHubLog -Message "Güncelleme başlatılamadı ($($package.Name)): $($_.Exception.Message)" -Color Red
        [void]$script:updateResults.Add([pscustomobject]@{ Name=$package.Name; Success=$false; Code=-1 })
        Add-FailedOperation -Item $package -Operation Upgrade -Code -1 -Detail $_.Exception.Message -Arguments $arguments
        $script:updateIndex++
        Start-NextUpdate
    }
}

$script:updateTimer.Add_Tick({
    if (-not $script:updateProcess) { return }
    $script:updateProcess.Refresh()
    if (-not $script:updateProcess.HasExited) { return }

    $script:updateTimer.Stop()
    $package = $script:updateQueue[$script:updateIndex]
    $script:updateProcess.WaitForExit()
    $exitCode = [int]$script:updateProcess.ExitCode
    $script:updateProcess.Dispose()
    $script:updateProcess = $null
    if ($exitCode -eq 0) {
        if ($script:detailMetadataCache) { [void]$script:detailMetadataCache.Remove([string]$package.Id) }
        Resolve-FailedOperation -Id $package.Id -Operation Upgrade
    } else {
        Add-FailedOperation -Item $package -Operation Upgrade -Code $exitCode -Detail 'WinGet güncellemesi tamamlanamadı'
    }
    [void]$script:updateResults.Add([pscustomobject]@{ Name=$package.Name; Success=($exitCode -eq 0); Code=$exitCode })
    Write-PowerHubLog -Message $(if ($exitCode -eq 0) { "Güncellendi: $($package.Name)" } else { "Güncellenemedi: $($package.Name), kod: $exitCode" }) -Color $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })
    $script:updateIndex++
    Start-NextUpdate
})

$controls.UpdateInstallButton.Add_Click({
    $script:updateQueue = @($script:updatePackages | Where-Object IsSelected | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            Id = $_.Id
            CurrentVersion = $_.CurrentVersion
            AvailableVersion = $_.AvailableVersion
            Source = $_.Source
        }
    })
    if ($script:updateQueue.Count -eq 0 -or $script:isInstalling) { return }

    $script:updateIndex = 0
    $script:updateResults = [Collections.ArrayList]::new()
    $script:isInstalling = $true
    $controls.UpdateInstallButton.IsEnabled = $false
    $controls.UpdateSelectAllButton.IsEnabled = $false
    $controls.UpdateRefreshButton.IsEnabled = $false
    $controls.UpdateProgress.Visibility = 'Visible'
    $controls.UpdateProgress.Value = 0
    Write-Host ''
    Write-PowerHubLog -Message "$($script:updateQueue.Count) paketlik güncelleme kuyruğu başlatıldı." -Color White
    Start-NextUpdate
})

$script:installQueue = @()
$script:installIndex = 0
$script:installResults = [Collections.ArrayList]::new()
$script:installProcess = $null
$script:installCancelled = $false
$script:installQueueItems = [Collections.ObjectModel.ObservableCollection[object]]::new()
$script:storeSourcePrepared = $false
$controls.InstallQueueList.ItemsSource = $script:installQueueItems
$script:installTimer = [Windows.Threading.DispatcherTimer]::new()
$script:installTimer.Interval = [TimeSpan]::FromMilliseconds(400)

function Set-InstallQueueVisibility {
    param([bool]$Visible)
    $wasVisible = $controls.InstallQueueOverlay.Visibility -eq [Windows.Visibility]::Visible
    if ($Visible -and -not $wasVisible) { Save-PowerHubFocus }
    $controls.InstallQueueOverlay.Visibility = if ($Visible) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    if ($Visible) { $controls.QueueCloseButton.Focus() | Out-Null }
    elseif ($wasVisible) { Restore-PowerHubFocus }
}

function Set-InstallQueueEntryState {
    param($Entry, [ValidateSet('Waiting','Running','Success','Failed','Manual','Cancelled')][string]$State, [string]$Detail, [int]$Code = 0)

    $Entry.Status = $State
    $Entry.Code = $Code
    if ($Detail) { $Entry.Detail = $Detail }
    switch ($State) {
        'Waiting'   { $Entry.StatusLabel='BEKLİYOR';    $Entry.StatusIcon='…'; $Entry.StatusBackground='#3A3F45'; $Entry.StatusForeground='#C2CBD1' }
        'Running'   { $Entry.StatusLabel='İŞLENİYOR';   $Entry.StatusIcon='↻'; $Entry.StatusBackground='#263F52'; $Entry.StatusForeground='#7DD3FC' }
        'Success'   { $Entry.StatusLabel='TAMAMLANDI';  $Entry.StatusIcon='✓'; $Entry.StatusBackground='#123B2C'; $Entry.StatusForeground='#6EE7B7' }
        'Failed'    { $Entry.StatusLabel='BAŞARISIZ';   $Entry.StatusIcon='!'; $Entry.StatusBackground='#543136'; $Entry.StatusForeground='#FFAAAA' }
        'Manual'    { $Entry.StatusLabel='SAYFA AÇILDI';$Entry.StatusIcon='↗'; $Entry.StatusBackground='#40365A'; $Entry.StatusForeground='#C6B7FF' }
        'Cancelled' { $Entry.StatusLabel='İPTAL';       $Entry.StatusIcon='×'; $Entry.StatusBackground='#3A3A3A'; $Entry.StatusForeground='#AEB7BD' }
    }
    $controls.InstallQueueList.Items.Refresh()
}

function Update-InstallQueueSummary {
    $total = $script:installQueueItems.Count
    $running = @($script:installQueueItems | Where-Object Status -eq 'Running')
    $waiting = @($script:installQueueItems | Where-Object Status -eq 'Waiting').Count
    $success = @($script:installQueueItems | Where-Object { $_.Status -in @('Success','Manual') }).Count
    $failed = @($script:installQueueItems | Where-Object Status -eq 'Failed').Count
    $cancelled = @($script:installQueueItems | Where-Object Status -eq 'Cancelled').Count
    $completed = $success + $failed + $cancelled

    $controls.QueueCountText.Text = "$total PAKET"
    $controls.QueueViewButton.Content = if ($total -gt 0) { "Kuyruk ($total)" } else { 'Kuyruk' }
    $controls.QueueViewButton.IsEnabled = ($total -gt 0)
    $controls.QueueProgress.Value = if ($total -gt 0) { [int](($completed / $total) * 100) } else { 0 }
    $controls.QueueRetryButton.IsEnabled = (-not $script:isInstalling -and $failed -gt 0)
    $controls.QueueCancelButton.IsEnabled = [bool]$script:isInstalling

    if ($total -eq 0) {
        $controls.QueueSummaryText.Text = 'Kuyruk henüz boş'
        $controls.QueueDetailText.Text = 'Kurulum, güncelleme ve kaldırma işlemleri burada görünür.'
        $controls.QueueFooterText.Text = 'Kuyruk beklemede'
    } elseif ($script:isInstalling -and $running.Count -gt 0) {
        $controls.QueueSummaryText.Text = "$($script:installIndex + 1) / $total paket işleniyor"
        $controls.QueueDetailText.Text = $running[0].Name
        $controls.QueueFooterText.Text = "$success tamamlandı • $waiting bekliyor"
    } elseif ($script:isInstalling) {
        $controls.QueueSummaryText.Text = "$total paketlik kuyruk hazırlanıyor"
        $controls.QueueDetailText.Text = 'İlk paket başlatılıyor...'
        $controls.QueueFooterText.Text = "$waiting paket bekliyor"
    } elseif ($script:installCancelled) {
        $controls.QueueSummaryText.Text = 'Kuyruk iptal edildi'
        $controls.QueueDetailText.Text = "$success tamamlandı • $cancelled iptal edildi"
        $controls.QueueFooterText.Text = 'İşlem kullanıcı tarafından durduruldu'
    } else {
        $controls.QueueSummaryText.Text = 'İşlem kuyruğu tamamlandı'
        $controls.QueueDetailText.Text = "$success tamamlandı • $failed başarısız"
        $controls.QueueFooterText.Text = if ($failed -gt 0) { 'Başarısız paketler yeniden denenebilir' } else { 'Tüm işlemler tamamlandı' }
    }
}

function New-InstallQueueEntry {
    param($App, [ValidateSet('Install','Upgrade','Uninstall')][string]$OperationOverride)
    $sourceIndex = if ($App.PSObject.Properties['InstallArguments']) { [Array]::IndexOf([object[]]@($App.InstallArguments), '--source') } else { -1 }
    $packageSource = if ($sourceIndex -ge 0 -and ($sourceIndex + 1) -lt @($App.InstallArguments).Count) { @($App.InstallArguments)[$sourceIndex + 1] } else { 'winget' }
    $operation = if ($OperationOverride) { $OperationOverride } else { $App.Operation }
    [pscustomobject]@{
        Name = $App.Name
        Id = $App.Id
        Action = if ($App.PSObject.Properties['Action']) { $App.Action } else { 'Winget' }
        Url = if ($App.PSObject.Properties['Url']) { $App.Url } else { $null }
        InstallArguments = if ($App.PSObject.Properties['InstallArguments']) { @($App.InstallArguments) } else { $null }
        Operation = $operation
        PackageSource = $packageSource
        Status = 'Waiting'
        StatusLabel = 'BEKLİYOR'
        StatusIcon = '…'
        StatusBackground = '#3A3F45'
        StatusForeground = '#C2CBD1'
        Detail = if ($operation -eq 'Uninstall') { 'Kaldırma için sırada' } elseif ($operation -eq 'Upgrade') { 'Güncelleme için sırada' } elseif ($App.PSObject.Properties['Action'] -and $App.Action -eq 'Url') { 'Resmî indirme sayfası için sırada' } else { 'Kurulum için sırada' }
        Code = 0
        StoreRetryCount = 0
    }
}

function Convert-FailureToQueueEntry {
    param($Failure)
    [pscustomobject]@{
        Name = [string]$Failure.Name
        Id = [string]$Failure.Id
        Action = if ($Failure.Operation -eq 'OpenUrl') { 'Url' } else { 'Winget' }
        Url = [string]$Failure.Website
        InstallArguments = @($Failure.InstallArguments)
        Operation = if ($Failure.Operation -eq 'OpenUrl') { 'Install' } else { [string]$Failure.Operation }
        PackageSource = if ($Failure.PackageSource) { [string]$Failure.PackageSource } else { 'winget' }
        Status = 'Waiting'
        StatusLabel = 'BEKLİYOR'
        StatusIcon = '…'
        StatusBackground = '#3A3F45'
        StatusForeground = '#C2CBD1'
        Detail = 'Başarısız İşlemler Merkezi üzerinden yeniden sırada'
        Code = 0
        StoreRetryCount = 0
    }
}

function Initialize-MicrosoftStoreSource {
    param([switch]$Force)

    if ($script:storeSourcePrepared -and -not $Force) { return $true }
    $winget = Resolve-WingetExecutable
    if (-not $winget) { return $false }

    $isWindowsSandbox = ($env:USERNAME -eq 'WDAGUtilityAccount') -or (Test-Path -LiteralPath 'C:\Users\WDAGUtilityAccount')
    try {
        if ($isWindowsSandbox) {
            # Windows Sandbox bazen geçerli bir mağaza bölgesi olmadan açılır.
            # Microsoft Store REST kaynağı bu durumda 0x8a15003b döndürür.
            try {
                $homeLocation = Get-WinHomeLocation -ErrorAction SilentlyContinue
                if (-not $homeLocation -or [int]$homeLocation.GeoId -ne 235) {
                    Set-WinHomeLocation -GeoId 235 -ErrorAction Stop
                    Write-PowerHubLog -Message 'Windows Sandbox mağaza bölgesi Türkiye olarak hazırlandı.' -Color DarkCyan
                }
            } catch {
                Write-PowerHubLog -Message "Sandbox mağaza bölgesi ayarlanamadı: $($_.Exception.Message)" -Color DarkYellow
            }
        }

        if ($Force -or $isWindowsSandbox) {
            Write-PowerHubLog -Message 'Microsoft Store paket kaynağı onarılıyor...' -Color DarkCyan
            & $winget source reset --force | Out-Host
        }
        & $winget source update --name msstore | Out-Host
        $script:storeSourcePrepared = ($LASTEXITCODE -eq 0)
        return $script:storeSourcePrepared
    } catch {
        Write-PowerHubLog -Message "Microsoft Store kaynağı hazırlanamadı: $($_.Exception.Message)" -Color DarkYellow
        return $false
    }
}

function Get-PackageOperationArguments {
    param($Item, [switch]$Interactive)
    $arguments = if ($Item.Operation -eq 'Uninstall') {
        @('uninstall','--id',$Item.Id,'--exact')
    } elseif ($Item.Operation -eq 'Upgrade') {
        @('upgrade','--id',$Item.Id,'--exact','--source',$Item.PackageSource,'--include-unknown')
    } elseif ($Item.InstallArguments -and @($Item.InstallArguments).Count -gt 0) {
        @($Item.InstallArguments)
    } else {
        @('install','--id',$Item.Id,'--exact')
    }
    if ($Item.Operation -ne 'Uninstall' -and $arguments -notcontains '--source') { $arguments += @('--source','winget') }
    $arguments += '--accept-source-agreements'
    if ($Item.Operation -ne 'Uninstall') { $arguments += '--accept-package-agreements' }
    if (-not $Interactive) { $arguments += @('--silent','--disable-interactivity') }
    return @($arguments)
}

function Test-WebView2RuntimeInstalled {
    $applicationRoots = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\EdgeWebView\Application'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\EdgeWebView\Application')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($root in $applicationRoots) {
        if (Get-ChildItem -LiteralPath $root -Filter 'msedgewebview2.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1) {
            return $true
        }
    }
    return $false
}

function Add-RequiredPackageDependencies {
    param([object[]]$Entries)

    $expandedEntries = @($Entries)
    $requiresWebView2 = @($expandedEntries | Where-Object {
        $_.Id -eq '9NKSQGP7F2NH' -and $_.Operation -ne 'Uninstall'
    }).Count -gt 0

    if ($requiresWebView2 -and -not (Test-WebView2RuntimeInstalled) -and @($expandedEntries | Where-Object Id -eq 'Microsoft.EdgeWebView2Runtime').Count -eq 0) {
        $dependency = [pscustomobject]@{
            Name = 'Microsoft Edge WebView2 Runtime'
            Id = 'Microsoft.EdgeWebView2Runtime'
            Action = 'Winget'
            Url = $null
            InstallArguments = $null
            Operation = 'Install'
            PackageSource = 'winget'
            Status = 'Waiting'
            StatusLabel = 'BEKLİYOR'
            StatusIcon = '…'
            StatusBackground = '#3A3F45'
            StatusForeground = '#C2CBD1'
            Detail = 'WhatsApp için gerekli çalışma bileşeni'
            Code = 0
            StoreRetryCount = 0
        }
        Write-PowerHubLog -Message 'WhatsApp bağımlılığı kuyruğa eklendi: Microsoft Edge WebView2 Runtime' -Color DarkCyan
        $expandedEntries = @($dependency) + $expandedEntries
    }
    return @($expandedEntries)
}

function Initialize-InstallQueue {
    param([object[]]$Entries)
    $Entries = @(Add-RequiredPackageDependencies -Entries $Entries)
    $script:installQueueItems.Clear()
    foreach ($entry in $Entries) {
        Set-InstallQueueEntryState -Entry $entry -State Waiting -Detail $entry.Detail
        [void]$script:installQueueItems.Add($entry)
    }
    $script:installQueue = @($Entries)
    $script:installIndex = 0
    $script:installResults = [Collections.ArrayList]::new()
    $script:installCancelled = $false
    Update-InstallQueueSummary
}

function Complete-InstallQueue {
    $script:installTimer.Stop()
    $script:isInstalling = $false
    $controls.SelectAllButton.IsEnabled = @($script:visibleApps | Where-Object { -not $_.IsWebResource -and $_.Operation -ne 'None' }).Count -gt 0
    $controls.InstallButton.IsEnabled = $true
    $controls.InstallProgress.Value = 100

    $failed = @($script:installResults | Where-Object { -not $_.Success })
    $manualCount = @($script:installResults | Where-Object Manual).Count
    $successCount = @($script:installResults | Where-Object { $_.Success -and -not $_.Manual }).Count
    $removedCount = @($script:installQueueItems | Where-Object { $_.Status -eq 'Success' -and $_.Operation -eq 'Uninstall' }).Count
    $changedCount = [Math]::Max(0, $successCount - $removedCount)
    $summaryParts = @()
    if ($changedCount -gt 0) { $summaryParts += "$changedCount kuruldu veya güncellendi" }
    if ($removedCount -gt 0) { $summaryParts += "$removedCount kaldırıldı" }
    if ($manualCount -gt 0) { $summaryParts += "$manualCount indirme sayfası açıldı" }
    $summary = if ($summaryParts.Count -gt 0) { $summaryParts -join ', ' } else { 'İşlem tamamlandı' }
    if ($failed.Count -eq 0) {
        Write-PowerHubLog -Message "İşlem tamamlandı: $summary." -Color Green
        $controls.ActivityText.Text = "$summary."
    } else {
        Write-PowerHubLog -Message "İşlem tamamlandı: $summary, $($failed.Count) başarısız." -Color Yellow
        $controls.ActivityText.Text = "$summary, $($failed.Count) başarısız."
    }
    Update-InstallQueueSummary
    Update-SelectionStatus
    Start-SystemScan -PreserveCurrentState
}

function Start-NextInstall {
    if ($script:installCancelled) { return }
    if ($script:installIndex -ge $script:installQueue.Count) {
        Complete-InstallQueue
        return
    }

    $item = $script:installQueue[$script:installIndex]
    $controls.InstallProgress.Value = [int](($script:installIndex / $script:installQueue.Count) * 100)
    Set-InstallQueueEntryState -Entry $item -State Running -Detail $(if ($item.Action -eq 'Url') { 'Resmî indirme sayfası açılıyor' } elseif ($item.Operation -eq 'Uninstall') { 'Paket kaldırılıyor' } elseif ($item.Operation -eq 'Upgrade') { 'Paket güncelleniyor' } else { 'Paket kuruluyor' })
    Update-InstallQueueSummary

    if ($item.Action -eq 'Url') {
        try {
            $controls.ActivityText.Text = "İndirme sayfası açılıyor: $($item.Name)"
            Write-PowerHubLog -Message "Resmî indirme sayfası açılıyor: $($item.Name)" -Color Cyan
            Start-Process -FilePath $item.Url
            [void]$script:installResults.Add([pscustomobject]@{ Name=$item.Name; Success=$true; Manual=$true; Code=0 })
            Set-InstallQueueEntryState -Entry $item -State Manual -Detail 'Resmî indirme sayfası açıldı'
        } catch {
            Write-PowerHubLog -Message "Sayfa açılamadı ($($item.Name)): $($_.Exception.Message)" -Color Red
            [void]$script:installResults.Add([pscustomobject]@{ Name=$item.Name; Success=$false; Manual=$true; Code=-1 })
            Set-InstallQueueEntryState -Entry $item -State Failed -Detail 'İndirme sayfası açılamadı' -Code -1
            Add-FailedOperation -Item $item -Operation OpenUrl -Code -1 -Detail $_.Exception.Message
        }
        $script:installIndex++
        Update-InstallQueueSummary
        Start-NextInstall
        return
    }

    $controls.ActivityText.Text = if ($item.Operation -eq 'Uninstall') { "Kaldırılıyor: $($item.Name)" } else { "Kuruluyor: $($item.Name)" }
    $installArguments = @(Get-PackageOperationArguments -Item $item)

    try {
        if ($item.Operation -ne 'Uninstall' -and $item.PackageSource -eq 'msstore') {
            [void](Initialize-MicrosoftStoreSource)
        }
        Write-PowerHubLog -Message $(if ($item.Operation -eq 'Uninstall') { "Kaldırılıyor: $($item.Name)" } else { "Kuruluyor: $($item.Name)" }) -Color Cyan
        Write-PowerHubLog -Message "Komut: winget $($installArguments -join ' ')" -Color DarkGray
        $script:wingetExecutable = Resolve-WingetExecutable
        if (-not $script:wingetExecutable) { throw 'winget çalıştırılabilir dosyası bulunamadı.' }
        $script:installProcess = Start-Process -FilePath $script:wingetExecutable -ArgumentList $installArguments -PassThru -NoNewWindow
        $script:installTimer.Start()
    } catch {
        Write-PowerHubLog -Message "Başlatma hatası ($($item.Name)): $($_.Exception.Message)" -Color Red
        [void]$script:installResults.Add([pscustomobject]@{ Name=$item.Name; Success=$false; Manual=$false; Code=-1 })
        Set-InstallQueueEntryState -Entry $item -State Failed -Detail 'İşlem başlatılamadı' -Code -1
        Add-FailedOperation -Item $item -Operation $item.Operation -Code -1 -Detail $_.Exception.Message -Arguments $installArguments
        $script:installIndex++
        Update-InstallQueueSummary
        Start-NextInstall
    }
}

function Test-PackageOperationApplied {
    param($Item)

    if (-not $script:wingetExecutable -or -not $Item.Id) { return $true }
    try {
        $listOutput = & $script:wingetExecutable list --id $Item.Id --exact --accept-source-agreements --disable-interactivity 2>&1 | Out-String
        $packageIsInstalled = ($LASTEXITCODE -eq 0 -and $listOutput -match [regex]::Escape([string]$Item.Id))
        if ($Item.Operation -eq 'Uninstall') { return (-not $packageIsInstalled) }
        return $packageIsInstalled
    } catch {
        Write-PowerHubLog -Message "Paket durumu doğrulanamadı ($($Item.Name)): $($_.Exception.Message)" -Color DarkYellow
        return $false
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
    $operationSucceeded = ($exitCode -eq 0)
    if ($operationSucceeded -and $item.Operation -in @('Install','Uninstall')) {
        $operationSucceeded = Test-PackageOperationApplied -Item $item
        if (-not $operationSucceeded) {
            if ($item.Operation -eq 'Install' -and $item.PackageSource -eq 'msstore' -and [int]$item.StoreRetryCount -lt 1) {
                $item.StoreRetryCount = [int]$item.StoreRetryCount + 1
                Write-PowerHubLog -Message "Microsoft Store işlemi doğrulanamadı; kaynak onarılıp yeniden deneniyor: $($item.Name)" -Color Yellow
                Set-InstallQueueEntryState -Entry $item -State Waiting -Detail 'Microsoft Store kaynağı onarılıyor; yeniden denenecek'
                $script:installProcess.Dispose()
                $script:installProcess = $null
                [void](Initialize-MicrosoftStoreSource -Force)
                Update-InstallQueueSummary
                Start-NextInstall
                return
            }
            $exitCode = -2
            Write-PowerHubLog -Message "WinGet başarı bildirdi ancak işlem doğrulanamadı: $($item.Name)" -Color Red
        }
    }
    if ($operationSucceeded) {
        Write-PowerHubLog -Message "Başarılı: $($item.Name), çıkış kodu: 0" -Color Green
        if ($script:detailMetadataCache) { [void]$script:detailMetadataCache.Remove([string]$item.Id) }
        Set-InstallQueueEntryState -Entry $item -State Success -Detail $(if ($item.Operation -eq 'Uninstall') { 'Kaldırma tamamlandı' } elseif ($item.Operation -eq 'Upgrade') { 'Güncelleme tamamlandı' } else { 'Kurulum tamamlandı' })
        $catalogApp = $apps | Where-Object Id -eq $item.Id | Select-Object -First 1
        if ($catalogApp) {
            Set-AppInstallState -App $catalogApp -State $(if ($item.Operation -eq 'Uninstall') { 'NotInstalled' } else { 'Installed' })
            Update-AppList
            Update-SelectionStatus
            Update-SystemScanSummary
        }
        Resolve-FailedOperation -Id $item.Id -Operation $item.Operation
    } else {
        Write-PowerHubLog -Message "Başarısız: $($item.Name), çıkış kodu: $exitCode" -Color Red
        $failureDetail = if ($exitCode -eq -2) { 'Kurulum durumu doğrulanamadı' } else { "WinGet çıkış kodu: $exitCode" }
        Set-InstallQueueEntryState -Entry $item -State Failed -Detail $failureDetail -Code $exitCode
        Add-FailedOperation -Item $item -Operation $item.Operation -Code $exitCode -Detail "WinGet işlemi tamamlanamadı" -Arguments (Get-PackageOperationArguments -Item $item)
    }
    [void]$script:installResults.Add([pscustomobject]@{ Name=$item.Name; Success=$operationSucceeded; Manual=$false; Code=$exitCode })
    $script:installProcess.Dispose()
    $script:installProcess = $null
    $script:installIndex++
    Update-InstallQueueSummary
    Start-NextInstall
})

function Start-InstallQueueExecution {
    if ($script:installQueue.Count -eq 0) { return }
    Write-Host ''
    $queueAction = if (@($script:installQueue | Where-Object Operation -eq 'Uninstall').Count -eq $script:installQueue.Count) { 'kaldırma' } else { 'paket işlemi' }
    Write-PowerHubLog -Message "$($script:installQueue.Count) uygulamalık $queueAction kuyruğu başlatıldı." -Color White
    $script:installIndex = 0
    $script:installResults = [Collections.ArrayList]::new()
    $script:installCancelled = $false
    $script:isInstalling = $true
    $controls.InstallButton.IsEnabled = $false
    $controls.SelectAllButton.IsEnabled = $false
    $controls.InstallProgress.Visibility = 'Visible'
    $controls.InstallProgress.Value = 0
    $controls.ActivityText.Text = if ($queueAction -eq 'kaldırma') { 'Kaldırma hazırlanıyor...' } else { 'Paket işlemleri hazırlanıyor...' }
    Set-InstallQueueVisibility $true
    Update-InstallQueueSummary
    Start-NextInstall
}

$script:pendingUninstallApp = $null
function Close-UninstallConfirmation {
    $wasVisible = $controls.UninstallConfirmOverlay.Visibility -eq [Windows.Visibility]::Visible
    $controls.UninstallConfirmOverlay.Visibility = [Windows.Visibility]::Collapsed
    $script:pendingUninstallApp = $null
    if ($wasVisible) { Restore-PowerHubFocus }
}

function Request-AppUninstall {
    param($App)
    if (-not $App -or $script:isInstalling -or $App.InstallState -notin @('Installed','UpdateAvailable')) { return }
    $script:pendingUninstallApp = $App
    Save-PowerHubFocus
    $controls.UninstallConfirmAppName.Text = $App.Name
    $controls.UninstallConfirmDetail.Text = "'$($App.Name)' bilgisayarınızdan ve WinGet paket listesinden kaldırılacak."
    $controls.UninstallConfirmOverlay.Visibility = [Windows.Visibility]::Visible
    $controls.UninstallCancelButton.Focus() | Out-Null
}

$controls.UninstallCancelButton.Add_Click({ Close-UninstallConfirmation })
$controls.UninstallConfirmBackdrop.Add_MouseLeftButtonUp({ Close-UninstallConfirmation })
$controls.UninstallConfirmButton.Add_Click({
    $appToRemove = $script:pendingUninstallApp
    if (-not $appToRemove) { Close-UninstallConfirmation; return }
    Close-UninstallConfirmation
    $appToRemove.IsSelected = $false
    $entry = New-InstallQueueEntry -App $appToRemove -OperationOverride Uninstall
    Initialize-InstallQueue -Entries @($entry)
    Start-InstallQueueExecution
})

$controls.InstallButton.Add_Click({
    $entries = @($apps | Where-Object { $_.IsSelected -and -not $_.IsWebResource -and $_.Operation -ne 'None' } | ForEach-Object { New-InstallQueueEntry -App $_ })
    if ($entries.Count -eq 0) { return }
    Initialize-InstallQueue -Entries $entries
    Start-InstallQueueExecution
})

$controls.QueueViewButton.Add_Click({ Set-InstallQueueVisibility $true })
$controls.QueueCloseButton.Add_Click({ Set-InstallQueueVisibility $false })
$controls.QueueBackdrop.Add_MouseLeftButtonUp({ Set-InstallQueueVisibility $false })
$controls.QueueCancelButton.Add_Click({
    if (-not $script:isInstalling) { return }
    $script:installCancelled = $true
    $script:installTimer.Stop()
    if ($script:installProcess) {
        if (-not $script:installProcess.HasExited) {
            Stop-Process -Id $script:installProcess.Id -Force -ErrorAction SilentlyContinue
        }
        $script:installProcess.Dispose()
        $script:installProcess = $null
    }
    foreach ($entry in @($script:installQueueItems | Where-Object { $_.Status -in @('Waiting','Running') })) {
        Set-InstallQueueEntryState -Entry $entry -State Cancelled -Detail 'Kuyruk iptal edildi' -Code -2
    }
    $script:isInstalling = $false
    $controls.InstallButton.IsEnabled = $true
    $controls.SelectAllButton.IsEnabled = $true
    $controls.InstallProgress.Value = 0
    $controls.ActivityText.Text = 'İşlem kuyruğu iptal edildi.'
    Write-PowerHubLog -Message 'İşlem kuyruğu kullanıcı tarafından iptal edildi.' -Color Yellow
    Update-InstallQueueSummary
})
$controls.QueueRetryButton.Add_Click({
    $failedEntries = @($script:installQueueItems | Where-Object Status -eq 'Failed')
    if ($failedEntries.Count -eq 0 -or $script:isInstalling) { return }
    foreach ($entry in $failedEntries) {
        Set-InstallQueueEntryState -Entry $entry -State Waiting -Detail $(if ($entry.Operation -eq 'Uninstall') { 'Kaldırma için yeniden sırada' } elseif ($entry.Operation -eq 'Upgrade') { 'Güncelleme için yeniden sırada' } else { 'Kurulum için yeniden sırada' })
    }
    Initialize-InstallQueue -Entries $failedEntries
    Start-InstallQueueExecution
})

function Set-WingetCardState {
    param([ValidateSet('Ready','Missing','Installing','Error')][string]$State)

    switch ($State) {
        'Ready' {
            $script:wingetReady = $true
            $controls.WingetCard.Cursor = [Windows.Input.Cursors]::Arrow
            $controls.WingetCard.BorderBrush = New-ColorBrush '#46515A'
            $controls.WingetIconBox.Background = New-ColorBrush '#123B2C'
            $controls.WingetIconBox.BorderBrush = New-ColorBrush '#236747'
            $controls.WingetIcon.Text = '✓'
            $controls.WingetIcon.Foreground = New-ColorBrush '#6EE7B7'
            $controls.WingetStatus.Text = 'WinGet'
            $controls.WingetDetail.Text = 'Paket yöneticisi çevrimiçi'
            $controls.WingetBadge.Background = New-ColorBrush '#123A2A'
            $controls.WingetBadge.BorderBrush = New-ColorBrush '#236747'
            $controls.WingetBadgeDot.Fill = New-ColorBrush '#67DB95'
            $controls.WingetBadgeText.Text = 'AKTİF'
            $controls.WingetBadgeText.Foreground = New-ColorBrush '#6EE7B7'
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
            $controls.WingetStatus.Text = 'winget hatası'
            $controls.WingetDetail.Text = 'Başarısız • yeniden denemek için tıklayın'
            $controls.WingetBadge.Background = New-ColorBrush '#542E32'
            $controls.WingetBadge.BorderBrush = New-ColorBrush '#A95454'
            $controls.WingetBadgeDot.Fill = New-ColorBrush '#FF7777'
            $controls.WingetBadgeText.Text = 'TEKRAR'
            $controls.WingetBadgeText.Foreground = New-ColorBrush '#FFAAAA'
        }
    }
    $controls.WingetStatus.Foreground = $window.FindResource('Ink')
    $controls.WingetDetail.Foreground = $window.FindResource('Muted')
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

$controls.WingetCard.Add_GotKeyboardFocus({
    $controls.WingetCard.Tag = $controls.WingetCard.BorderBrush
    $controls.WingetCard.BorderBrush = New-ColorBrush '#A5F3FC'
    $controls.WingetCard.BorderThickness = [Windows.Thickness]::new(2)
})
$controls.WingetCard.Add_LostKeyboardFocus({
    if ($controls.WingetCard.Tag) { $controls.WingetCard.BorderBrush = $controls.WingetCard.Tag }
    $controls.WingetCard.BorderThickness = [Windows.Thickness]::new(1)
})
$controls.WingetCard.Add_KeyDown({
    param($sender,$eventArgs)
    if ($eventArgs.Key -in @([Windows.Input.Key]::Enter,[Windows.Input.Key]::Space)) {
        $mouseArgs = [Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,[Environment]::TickCount,[Windows.Input.MouseButton]::Left)
        $mouseArgs.RoutedEvent = [Windows.UIElement]::MouseLeftButtonUpEvent
        $controls.WingetCard.RaiseEvent($mouseArgs)
        $eventArgs.Handled = $true
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

    if ($env:USERNAME -eq 'WDAGUtilityAccount') {
        try {
            Set-WinHomeLocation -GeoId 235 -ErrorAction Stop
            Write-Host '[PowerHub] Windows Sandbox mağaza bölgesi hazırlandı: Türkiye' -ForegroundColor DarkCyan
        } catch {
            Write-Host "[PowerHub] Sandbox mağaza bölgesi ayarlanamadı: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

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
Update-UpdateCenterSelectionStatus
Update-InstallQueueSummary
Import-FailedOperations
Set-PowerHubWindowLayout
Write-PowerHubLog -Message 'PowerHub hazır. Kurulum günlükleri bu terminalde gösterilecek.' -Color Cyan
if ($winget) { Start-SystemScan }
$window.Add_Closed({
    Stop-AppDetailMetadataLoad
    if ($script:themeWatchTimer) { $script:themeWatchTimer.Stop() }
    $script:systemScanTimer.Stop()
    $script:securityScanTimer.Stop()
    $script:updateTimer.Stop()
    $script:installTimer.Stop()
    if ($script:systemScanProcess -and -not $script:systemScanProcess.HasExited) {
        Stop-Process -Id $script:systemScanProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($script:systemScanResultFile) { Remove-Item -LiteralPath $script:systemScanResultFile -Force -ErrorAction SilentlyContinue }
    if ($script:securityScanProcess -and -not $script:securityScanProcess.HasExited) {
        Stop-Process -Id $script:securityScanProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($script:securityScanResultFile) { Remove-Item -LiteralPath $script:securityScanResultFile -Force -ErrorAction SilentlyContinue }
    if ($script:updateProcess -and -not $script:updateProcess.HasExited) {
        Stop-Process -Id $script:updateProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($script:installProcess -and -not $script:installProcess.HasExited) {
        Stop-Process -Id $script:installProcess.Id -Force -ErrorAction SilentlyContinue
    }
})
$window.Add_ContentRendered({
    $activeNav = @($controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] -and [string]$_.Tag -eq $script:activeCategory } | Select-Object -First 1)
    if ($activeNav.Count -gt 0) { $activeNav[0].Focus() | Out-Null } else { $controls.SearchBox.Focus() | Out-Null }
})
$window.ShowDialog() | Out-Null
