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
}
'@

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerHub" Width="780" Height="900" MinWidth="700" MinHeight="700"
        WindowStartupLocation="Manual" Background="{DynamicResource PageBg}"
        FontFamily="Segoe UI Variable, Segoe UI" TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType" TextOptions.TextHintingMode="Fixed"
        UseLayoutRounding="True" SnapsToDevicePixels="True">
    <Window.Resources>
        <SolidColorBrush x:Key="Primary" Color="#0078D4"/>
        <SolidColorBrush x:Key="Ink" Color="#F0F3F5"/>
        <SolidColorBrush x:Key="Muted" Color="#AAB3BC"/>
        <SolidColorBrush x:Key="PageBg" Color="#252A30"/>
        <SolidColorBrush x:Key="CardBg" Color="#30363D"/>
        <SolidColorBrush x:Key="CardBorder" Color="#454D56"/>
        <SolidColorBrush x:Key="SoftBg" Color="#263F52"/>
        <SolidColorBrush x:Key="SoftText" Color="#82CEFF"/>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}"
                                CornerRadius="9" Padding="{TemplateBinding Padding}">
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
            <Setter Property="Foreground" Value="#D7DEF0"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Margin" Value="0,3"/>
            <Setter Property="Padding" Value="8,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="NavBorder" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="11" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="NavBorder" Property="Background" Value="#394149"/>
                                <Setter TargetName="NavBorder" Property="BorderBrush" Value="#526270"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="NavBorder" Property="Background" Value="#174C70"/>
                            </Trigger>
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
                            <Border x:Name="CheckBorder" Background="#292F35" BorderBrush="#7B8792"
                                    BorderThickness="1.2" CornerRadius="5"/>
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
            <ColumnDefinition Width="200"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Border x:Name="Sidebar" Grid.Column="0" BorderThickness="0">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                    <GradientStop Color="#24272B" Offset="0"/>
                    <GradientStop Color="#35393E" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
            <Grid Margin="18,24">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <StackPanel Orientation="Horizontal" Margin="8,0,0,25">
                    <Border Width="40" Height="40" CornerRadius="12">
                        <Border.Background>
                            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                <GradientStop Color="#0EA5E9" Offset="0"/>
                                <GradientStop Color="#0067C0" Offset="1"/>
                            </LinearGradientBrush>
                        </Border.Background>
                        <Border.Effect><DropShadowEffect Color="#071A29" BlurRadius="14" ShadowDepth="3" Opacity="0.48"/></Border.Effect>
                        <TextBlock Text="P" Foreground="White" FontSize="20" FontWeight="Bold"
                                   HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Margin="11,0,0,0">
                        <TextBlock Text="PowerHub" Foreground="White" FontWeight="Bold" FontSize="17"/>
                        <TextBlock Text="Uygulama merkezi" Foreground="#9CB1C2" FontSize="10" Margin="0,2,0,0"/>
                    </StackPanel>
                </StackPanel>

                <Grid Grid.Row="1" Margin="8,0,8,8">
                    <TextBlock Text="KATEGORİLER" Foreground="#7F94A6" FontSize="9" FontWeight="Bold"/>
                    <Border Height="1" Background="#485058" Margin="78,6,0,0"/>
                </Grid>
                <StackPanel Grid.Row="2">
                    <StackPanel x:Name="CategoryPanel"/>
                    <Border BorderBrush="#2E769F" BorderThickness="1" CornerRadius="14" Padding="11" Margin="0,17,0,0">
                        <Border.Background>
                            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#123B55" Offset="0"/><GradientStop Color="#205B73" Offset="1"/></LinearGradientBrush>
                        </Border.Background>
                        <Grid>
                            <Grid.ColumnDefinitions><ColumnDefinition Width="40"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <Border Width="33" Height="33" Background="#0786D1" CornerRadius="10">
                                <Border.Effect><DropShadowEffect Color="#06283C" BlurRadius="10" ShadowDepth="2" Opacity="0.5"/></Border.Effect>
                                <TextBlock Text="⚡" Foreground="White" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Tek tıkla kurulum" Foreground="White" FontSize="11" FontWeight="SemiBold"/>
                                <TextBlock Text="Sessiz • Güvenli • Güncel" Foreground="#9DD5F2" FontSize="8" Margin="0,3,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" Foreground="#8FD8FF" FontSize="20" VerticalAlignment="Center"/>
                        </Grid>
                    </Border>
                </StackPanel>

                <Border Grid.Row="3" BorderBrush="#545A61" BorderThickness="1" CornerRadius="14" Padding="10">
                    <Border.Background>
                        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                            <GradientStop Color="#3B3F44" Offset="0"/>
                            <GradientStop Color="#33373B" Offset="1"/>
                        </LinearGradientBrush>
                    </Border.Background>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="34"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name="WingetIconBox" Width="28" Height="28" Background="#214B35" CornerRadius="9">
                            <TextBlock x:Name="WingetIcon" Text="✓" Foreground="#7EE2A8" FontSize="14" FontWeight="Bold"
                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                            <TextBlock x:Name="WingetStatus" Text="winget kontrol ediliyor" Foreground="White"
                                       FontSize="11" FontWeight="SemiBold"/>
                            <TextBlock x:Name="WingetDetail" Text="Kurulum motoru" Foreground="#91A0AF"
                                       FontSize="9" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Border x:Name="WingetBadge" Grid.Column="2" Background="#204A32" CornerRadius="8"
                                Padding="6,4" VerticalAlignment="Center">
                            <TextBlock x:Name="WingetBadgeText" Text="AKTİF" Foreground="#7EE2A8"
                                       FontSize="8" FontWeight="Bold"/>
                        </Border>
                    </Grid>
                </Border>
            </Grid>
        </Border>

        <Grid Grid.Column="1" Margin="22,20,22,18">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Border x:Name="HeaderBanner" CornerRadius="18" Padding="20,17" Background="{DynamicResource CardBg}"
                    BorderBrush="{DynamicResource CardBorder}" BorderThickness="1">
                <Border.Effect><DropShadowEffect Color="#0E1114" BlurRadius="18" ShadowDepth="3" Opacity="0.30"/></Border.Effect>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="58"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="210"/>
                    </Grid.ColumnDefinitions>
                    <Border Width="46" Height="46" Background="{DynamicResource Primary}" CornerRadius="14"
                            VerticalAlignment="Top" HorizontalAlignment="Left">
                        <Border.Effect><DropShadowEffect Color="#0078D4" BlurRadius="12" ShadowDepth="2" Opacity="0.30"/></Border.Effect>
                        <Grid>
                            <Rectangle Width="21" Height="17" Fill="Transparent" Stroke="White" StrokeThickness="1.8" RadiusX="3" RadiusY="3"/>
                            <Path Data="M 15 17 L 23 17 M 19 13 L 19 21" Stroke="White" StrokeThickness="1.8"
                                  StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                        </Grid>
                    </Border>
                    <StackPanel Grid.Column="1">
                        <TextBlock Text="Paket merkezi" FontSize="25" FontWeight="Bold" Foreground="{DynamicResource Ink}"/>
                        <TextBlock Text="Seç, kur ve devam et."
                                   Foreground="{DynamicResource Muted}" FontSize="13" Margin="0,4,0,0"/>
                        <StackPanel Orientation="Horizontal" Margin="0,11,0,0">
                            <Border Background="{DynamicResource SoftBg}" CornerRadius="9" Padding="9,4" Margin="0,0,7,0">
                                <TextBlock x:Name="TotalAppBadgeText" Text="0 uygulama" Foreground="{DynamicResource SoftText}" FontSize="10" FontWeight="SemiBold"/>
                            </Border>
                            <Border Background="#203B2C" CornerRadius="9" Padding="9,4">
                                <TextBlock Text="●  Sistem hazır" Foreground="#70D596" FontSize="10" FontWeight="SemiBold"/>
                            </Border>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Grid.Column="2" VerticalAlignment="Center">
                        <Border Background="#292F35" BorderBrush="{DynamicResource CardBorder}"
                                BorderThickness="1" CornerRadius="11" Height="42">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="38"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <TextBlock Text="⌕" FontSize="22" Foreground="#AAB3BC" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                <TextBox x:Name="SearchBox" Grid.Column="1" BorderThickness="0" Background="Transparent"
                                         VerticalContentAlignment="Center" FontSize="13" Foreground="{DynamicResource Ink}" CaretBrush="{DynamicResource Primary}"
                                         ToolTip="Uygulama ara..." Margin="0,0,8,0"/>
                            </Grid>
                        </Border>
                        <Grid Margin="3,9,3,0">
                            <TextBlock Text="WINGET KATALOĞU" Foreground="{DynamicResource Muted}" FontSize="9" FontWeight="Bold"/>
                            <TextBlock Text="GÜVENLİ • REKLAMSIZ" HorizontalAlignment="Right" Foreground="#70D596" FontSize="9" FontWeight="Bold"/>
                        </Grid>
                    </StackPanel>
                </Grid>
            </Border>

            <Grid Grid.Row="1" Margin="0,18,0,12">
                <TextBlock x:Name="SectionTitle" Text="Tüm uygulamalar" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource Ink}"/>
                <TextBlock x:Name="ResultCount" HorizontalAlignment="Right" Foreground="{StaticResource Muted}" FontSize="12"/>
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
                                    <Grid Background="#252A30">
                                        <Track x:Name="PART_Track" IsDirectionReversed="True">
                                            <Track.DecreaseRepeatButton>
                                                <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0"/>
                                            </Track.DecreaseRepeatButton>
                                            <Track.Thumb>
                                                <Thumb>
                                                    <Thumb.Template>
                                                        <ControlTemplate TargetType="Thumb">
                                                            <Border Background="#5A6570" CornerRadius="4" Margin="2,0"/>
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
                        <Setter Property="Padding" Value="0"/><Setter Property="Margin" Value="0,0,0,8"/>
                        <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                        <Setter Property="Template">
                            <Setter.Value><ControlTemplate TargetType="ListBoxItem"><ContentPresenter/></ControlTemplate></Setter.Value>
                        </Setter>
                    </Style>
                </ListBox.ItemContainerStyle>
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <Border Height="70" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1"
                                CornerRadius="11" Padding="0" ClipToBounds="True" SnapsToDevicePixels="True">
                            <Border.Effect><DropShadowEffect Color="#101419" BlurRadius="9" ShadowDepth="1" Opacity="0.28"/></Border.Effect>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="4"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Background="{Binding Color}"/>
                                <Grid Grid.Column="1" Margin="11,7,10,7">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="43"/><ColumnDefinition Width="*"/><ColumnDefinition Width="25"/></Grid.ColumnDefinitions>
                                    <Border Width="36" Height="36" Background="{Binding Color}" CornerRadius="10" VerticalAlignment="Center">
                                        <Border.Effect><DropShadowEffect Color="#687078" BlurRadius="7" ShadowDepth="1" Opacity="0.22"/></Border.Effect>
                                        <Grid>
                                            <Image Source="{Binding Logo}" Width="27" Height="27" Stretch="Uniform"
                                                   HorizontalAlignment="Center" VerticalAlignment="Center" SnapsToDevicePixels="True"/>
                                            <TextBlock Text="{Binding Initial}" Opacity="{Binding InitialOpacity}" Foreground="White" FontWeight="Bold" FontSize="14"
                                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>
                                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="1,0,6,0">
                                        <TextBlock Text="{Binding Name}" Foreground="{DynamicResource Ink}" FontWeight="SemiBold" FontSize="13"
                                                   TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Text="{Binding Description}" Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,2,0,0"
                                                   TextTrimming="CharacterEllipsis"/>
                                    </StackPanel>
                                    <CheckBox Grid.Column="2" IsChecked="{Binding IsSelected, Mode=TwoWay}"
                                              VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                </Grid>
                            </Grid>
                        </Border>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>

            <Border Grid.Row="3" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1" CornerRadius="13"
                    Padding="16,12" Margin="0,8,0,0">
                <Border.Effect><DropShadowEffect Color="#0E1114" BlurRadius="16" ShadowDepth="2" Opacity="0.28"/></Border.Effect>
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock x:Name="SelectionText" Text="Henüz uygulama seçilmedi" Foreground="{DynamicResource Ink}" FontWeight="SemiBold"/>
                        <TextBlock x:Name="ActivityText" Text="Kurulacak uygulamaları işaretleyin." Foreground="{DynamicResource Muted}" FontSize="11" Margin="0,3,0,0"/>
                        <ProgressBar x:Name="InstallProgress" Height="4" Margin="0,8,18,0" Minimum="0" Maximum="100"
                                     Value="0" Visibility="Collapsed" Foreground="{DynamicResource Primary}" Background="{DynamicResource SoftBg}"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <Button x:Name="SelectAllButton" Content="Görünenleri seç" Background="{DynamicResource SoftBg}" Foreground="{DynamicResource SoftText}" Margin="0,0,9,0"/>
                        <Button x:Name="InstallButton" Content="Kurulumu başlat  →" Background="{DynamicResource Primary}" Foreground="White" IsEnabled="False"/>
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
@('Sidebar','HeaderBanner','CategoryPanel','WingetIconBox','WingetIcon','WingetStatus','WingetDetail','WingetBadge','WingetBadgeText','TotalAppBadgeText','SearchBox','SectionTitle','ResultCount','AppList','SelectionText',
  'ActivityText','InstallProgress','SelectAllButton','InstallButton') | ForEach-Object {
    $controls[$_] = $window.FindName($_)
}

function New-ColorBrush([string]$color) {
    return [Windows.Media.BrushConverter]::new().ConvertFromString($color)
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
    $developmentPath = Join-Path $PSScriptRoot 'PowerHub\logos.json'
    $catalogPath = @(
        (Join-Path $PSScriptRoot 'logos.json'),
        $developmentPath,
        $cachePath
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    try {
        if (-not $catalogPath) {
            [IO.Directory]::CreateDirectory($cacheDirectory) | Out-Null
            $response = Invoke-WebRequest -UseBasicParsing -Uri 'https://bygog.github.io/PowerHub/logos.json' -TimeoutSec 15
            $json = if ($response.Content -is [byte[]]) {
                [Text.Encoding]::UTF8.GetString([byte[]]$response.Content)
            } else {
                [string]$response.Content
            }
            [IO.File]::WriteAllText($cachePath, $json, [Text.UTF8Encoding]::new($false))
            $catalogPath = $cachePath
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
    $window.Width = 780
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
    [pscustomobject]@{ Name='Everything'; Description='Anında dosya arama'; Id='voidtools.Everything'; Category='Sistem Araçları'; Initial='E'; Color='#F97316'; IsSelected=$false },

    [pscustomobject]@{ Name='Malwarebytes'; Description='Kötü amaçlı yazılım koruması'; Id='Malwarebytes.Malwarebytes'; Category='Güvenlik'; Initial='M'; Color='#1479C9'; IsSelected=$false },
    [pscustomobject]@{ Name='Bitwarden'; Description='Açık kaynak parola yöneticisi'; Id='Bitwarden.Bitwarden'; Category='Güvenlik'; Initial='B'; Color='#175DDC'; IsSelected=$false },
    [pscustomobject]@{ Name='ESET Security'; Description='Antivirüs ve internet güvenliği'; Id='ESET.Security'; Category='Güvenlik'; Initial='E'; Color='#00A6A6'; IsSelected=$false },
    [pscustomobject]@{ Name='Sandboxie Plus'; Description='Yalıtılmış uygulama ortamı'; Id='Sandboxie.Plus'; Category='Güvenlik'; Initial='S'; Color='#D5A62E'; IsSelected=$false },

    [pscustomobject]@{ Name='Proton VPN'; Description='Gizlilik odaklı VPN'; Id='Proton.ProtonVPN'; Category='Gizlilik & Ağ'; Initial='P'; Color='#6D4AFF'; IsSelected=$false },
    [pscustomobject]@{ Name='OpenVPN Connect'; Description='Güvenli VPN istemcisi'; Id='OpenVPNTechnologies.OpenVPNConnect'; Category='Gizlilik & Ağ'; Initial='O'; Color='#EA7E20'; IsSelected=$false },
    [pscustomobject]@{ Name='GoodbyeDPI'; Description='DPI engellerine karşı ağ aracı'; Id='ValdikSS.GoodbyeDPI'; Category='Gizlilik & Ağ'; Initial='G'; Color='#3D7B8A'; IsSelected=$false },
    [pscustomobject]@{ Name='DNS Jumper'; Description='Hızlı DNS değiştirme aracı'; Id='sordum.DnsJumper'; Category='Gizlilik & Ağ'; Initial='D'; Color='#3A8A7A'; IsSelected=$false },

    [pscustomobject]@{ Name='Steam'; Description='PC oyun mağazası ve platformu'; Id='Valve.Steam'; Category='Oyun & Platformlar'; Initial='S'; Color='#1B6B9B'; IsSelected=$false },
    [pscustomobject]@{ Name='Epic Games Launcher'; Description='Epic oyun mağazası'; Id='EpicGames.EpicGamesLauncher'; Category='Oyun & Platformlar'; Initial='E'; Color='#4B4B4B'; IsSelected=$false },
    [pscustomobject]@{ Name='Battle.net'; Description='Blizzard oyun platformu'; Id='Blizzard.BattleNet'; Category='Oyun & Platformlar'; Initial='B'; Color='#148EFF'; IsSelected=$false },
    [pscustomobject]@{ Name='GOG Galaxy'; Description='GOG oyun kütüphanesi'; Id='GOG.Galaxy'; Category='Oyun & Platformlar'; Initial='G'; Color='#8B4FA8'; IsSelected=$false },

    [pscustomobject]@{ Name='7-Zip'; Description='Hafif arşiv yöneticisi'; Id='7zip.7zip'; InstallArguments=@('install','-e','--id','7zip.7zip'); Category='Dosya Yönetimi'; Initial='7'; InitialOpacity=0.0; Logo=$sevenZipLogo; Color='#6B7280'; IsSelected=$false },
    [pscustomobject]@{ Name='WinRAR'; Description='Arşivleme ve sıkıştırma aracı'; Id='RARLab.WinRAR'; Category='Dosya Yönetimi'; Initial='W'; Color='#7A5B91'; IsSelected=$false },
    [pscustomobject]@{ Name='WizTree'; Description='Hızlı disk alanı analizi'; Id='AntibodySoftware.WizTree'; Category='Dosya Yönetimi'; Initial='W'; Color='#49944A'; IsSelected=$false },
    [pscustomobject]@{ Name='TeraCopy'; Description='Hızlı ve güvenilir dosya kopyalama'; Id='CodeSector.TeraCopy'; Category='Dosya Yönetimi'; Initial='T'; Color='#3D7FA5'; IsSelected=$false },
    [pscustomobject]@{ Name='OneCommander'; Description='Modern çift panelli dosya yöneticisi'; Id='MilosParipovic.OneCommander'; Category='Dosya Yönetimi'; Initial='1'; Color='#4B79A8'; IsSelected=$false },

    [pscustomobject]@{ Name='VirtualBox'; Description='Açık kaynak sanallaştırma'; Id='Oracle.VirtualBox'; Category='Sanallaştırma'; Initial='V'; Color='#2366A8'; IsSelected=$false },
    [pscustomobject]@{ Name='VirtualBox Extension Pack'; Description='USB ve uzak bağlantı eklentileri'; Action='Url'; Url='https://www.virtualbox.org/wiki/Downloads'; Category='Sanallaştırma'; Initial='V+'; Color='#376F9C'; IsSelected=$false },
    [pscustomobject]@{ Name='VMware Workstation Pro'; Description='Profesyonel masaüstü sanallaştırma'; Action='Url'; Url='https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion'; Category='Sanallaştırma'; Initial='VM'; Color='#E28A24'; IsSelected=$false },

    [pscustomobject]@{ Name='Office Tool Plus'; Description='Office dağıtım ve yönetim aracı'; Id='Yerong.OfficeToolPlus'; Category='Betikler & Otomasyon'; Initial='O'; Color='#D64A3A'; IsSelected=$false },
    [pscustomobject]@{ Name='CTT WinUtil'; Description='Windows bakım ve yapılandırma aracı'; Action='Url'; Url='https://github.com/ChrisTitusTech/winutil'; Category='Betikler & Otomasyon'; Initial='W'; Color='#4C8B69'; IsSelected=$false }
)

foreach ($app in $apps) {
    if (-not $app.PSObject.Properties['Logo']) {
        $app | Add-Member -NotePropertyName Logo -NotePropertyValue $null
    }
    if (-not $app.PSObject.Properties['InitialOpacity']) {
        $app | Add-Member -NotePropertyName InitialOpacity -NotePropertyValue 1.0
    }
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
    [pscustomobject]@{ Name='Tümü'; Display='Tüm uygulamalar'; Icon='▦'; Background='#087BBE'; Foreground='#FFFFFF' },
    [pscustomobject]@{ Name='Web Tarayıcıları'; Display='Web Tarayıcıları'; Icon='◎'; Background='#334D5E'; Foreground='#7DD3FC' },
    [pscustomobject]@{ Name='İletişim & Sosyal'; Display='İletişim & Sosyal'; Icon='✉'; Background='#433C59'; Foreground='#C4B5FD' },
    [pscustomobject]@{ Name='Üretkenlik'; Display='Üretkenlik'; Icon='◆'; Background='#3D5258'; Foreground='#9ED5D8' },
    [pscustomobject]@{ Name='Multimedya'; Display='Multimedya'; Icon='▷'; Background='#574632'; Foreground='#FCD34D' },
    [pscustomobject]@{ Name='Geliştirme'; Display='Geliştirme'; Icon='</>'; Background='#284B47'; Foreground='#6EE7B7' },
    [pscustomobject]@{ Name='Yapay Zeka'; Display='Yapay Zeka'; Icon='✦'; Background='#51405E'; Foreground='#D8B4FE' },
    [pscustomobject]@{ Name='Donanım & Test'; Display='Donanım & Test'; Icon='◫'; Background='#55473D'; Foreground='#F5C59B' },
    [pscustomobject]@{ Name='Sistem Araçları'; Display='Sistem Araçları'; Icon='⚙'; Background='#3B485A'; Foreground='#93C5FD' },
    [pscustomobject]@{ Name='Güvenlik'; Display='Güvenlik'; Icon='◇'; Background='#563C43'; Foreground='#FDA4AF' },
    [pscustomobject]@{ Name='Gizlilik & Ağ'; Display='Gizlilik & Ağ'; Icon='⌁'; Background='#34545B'; Foreground='#8FE3E8' },
    [pscustomobject]@{ Name='Oyun & Platformlar'; Display='Oyun & Platformlar'; Icon='◈'; Background='#40533B'; Foreground='#B7E39B' },
    [pscustomobject]@{ Name='Dosya Yönetimi'; Display='Dosya Yönetimi'; Icon='▤'; Background='#56503D'; Foreground='#E8D897' },
    [pscustomobject]@{ Name='Sanallaştırma'; Display='Sanallaştırma'; Icon='⬡'; Background='#444A68'; Foreground='#B8C2FF' },
    [pscustomobject]@{ Name='Betikler & Otomasyon'; Display='Betikler & Otomasyon'; Icon='⚡'; Background='#55435B'; Foreground='#E8B8F3' }
)

foreach ($category in $categoryDefinitions) {
    $count = if ($category.Name -eq 'Tümü') { $apps.Count } else { @($apps | Where-Object Category -eq $category.Name).Count }
    $button = [Windows.Controls.Button]::new()
    $button.Style = $window.Resources['NavButton']
    $button.Tag = $category.Name
    $button.ToolTip = $category.Display
    $button.Margin = [Windows.Thickness]::new(0,1,0,1)
    $button.Padding = [Windows.Thickness]::new(7,4,7,4)
    if ($category.Name -eq 'Tümü') {
        $button.Background = New-ColorBrush '#174C70'
        $button.BorderBrush = New-ColorBrush '#278DD1'
    }

    $grid = [Windows.Controls.Grid]::new()
    $grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $grid.ColumnDefinitions[0].Width = [Windows.GridLength]::new(30)
    $grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $grid.ColumnDefinitions[1].Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $grid.ColumnDefinitions[2].Width = [Windows.GridLength]::Auto

    $iconBox = [Windows.Controls.Border]::new()
    $iconBox.Width = 24
    $iconBox.Height = 24
    $iconBox.CornerRadius = [Windows.CornerRadius]::new(7)
    $iconBox.Background = New-ColorBrush $category.Background
    $icon = [Windows.Controls.TextBlock]::new()
    $icon.Text = $category.Icon
    $icon.Foreground = New-ColorBrush $category.Foreground
    $icon.FontSize = if ($category.Icon -eq '</>') { 8 } else { 11 }
    $icon.FontWeight = [Windows.FontWeights]::SemiBold
    $icon.HorizontalAlignment = 'Center'
    $icon.VerticalAlignment = 'Center'
    $iconBox.Child = $icon

    $label = [Windows.Controls.TextBlock]::new()
    $label.Text = $category.Display
    $label.Foreground = New-ColorBrush '#E7EDF3'
    $label.FontSize = 9.5
    $label.FontWeight = if ($category.Name -eq 'Tümü') { [Windows.FontWeights]::SemiBold } else { [Windows.FontWeights]::Normal }
    $label.VerticalAlignment = 'Center'
    $label.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
    [Windows.Controls.Grid]::SetColumn($label, 1)

    $countText = [Windows.Controls.TextBlock]::new()
    $countText.Text = [string]$count
    $countText.Foreground = New-ColorBrush '#8FA2B2'
    $countText.FontSize = 8
    $countText.VerticalAlignment = 'Center'
    $countText.Margin = [Windows.Thickness]::new(4,0,3,0)
    [Windows.Controls.Grid]::SetColumn($countText, 2)

    [void]$grid.Children.Add($iconBox)
    [void]$grid.Children.Add($label)
    [void]$grid.Children.Add($countText)
    $button.Content = $grid
    [void]$controls.CategoryPanel.Children.Add($button)
}

$controls.TotalAppBadgeText.Text = "{0} uygulama" -f $apps.Count

$script:activeCategory = 'Tümü'
$script:isInstalling = $false
$script:visibleApps = @()

function Update-SelectionStatus {
    $selected = @($apps | Where-Object IsSelected)
    if ($selected.Count -eq 0) {
        $controls.SelectionText.Text = 'Henüz uygulama seçilmedi'
        $controls.ActivityText.Text = 'Kurulacak uygulamaları işaretleyin.'
    } else {
        $controls.SelectionText.Text = "{0} uygulama kurulacak" -f $selected.Count
        if (-not $script:isInstalling) { $controls.ActivityText.Text = ($selected.Name -join ', ') }
    }
    $controls.InstallButton.IsEnabled = ($selected.Count -gt 0 -and -not $script:isInstalling -and (Get-Command winget.exe -ErrorAction SilentlyContinue))
}

function Update-AppList {
    $search = $controls.SearchBox.Text.Trim()
    $script:visibleApps = @($apps | Where-Object {
        ($script:activeCategory -eq 'Tümü' -or $_.Category -eq $script:activeCategory) -and
        ([string]::IsNullOrWhiteSpace($search) -or $_.Name -like "*$search*" -or $_.Description -like "*$search*")
    })
    $controls.AppList.ItemsSource = $null
    $controls.AppList.ItemsSource = $script:visibleApps
    $controls.ResultCount.Text = "{0} uygulama" -f $script:visibleApps.Count
    $controls.SectionTitle.Text = if ($script:activeCategory -eq 'Tümü') { 'Tüm uygulamalar' } else { $script:activeCategory }
}

$controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] } | ForEach-Object {
    $button = $_
    $button.Add_Click({
        param($sender, $eventArgs)
        $script:activeCategory = [string]$sender.Tag
        foreach ($nav in @($controls.CategoryPanel.Children | Where-Object { $_ -is [Windows.Controls.Button] })) {
            $nav.Background = [Windows.Media.Brushes]::Transparent
            $nav.BorderBrush = [Windows.Media.Brushes]::Transparent
        }
        $sender.Background = New-ColorBrush '#174C70'
        $sender.BorderBrush = New-ColorBrush '#278DD1'
        Update-AppList
    })
}

$controls.SearchBox.Add_TextChanged({ Update-AppList })
$controls.AppList.AddHandler([Windows.Controls.CheckBox]::CheckedEvent, [Windows.RoutedEventHandler]{ Update-SelectionStatus })
$controls.AppList.AddHandler([Windows.Controls.CheckBox]::UncheckedEvent, [Windows.RoutedEventHandler]{ Update-SelectionStatus })

$controls.SelectAllButton.Add_Click({
    $allSelected = $script:visibleApps.Count -gt 0 -and @($script:visibleApps | Where-Object { -not $_.IsSelected }).Count -eq 0
    foreach ($app in $script:visibleApps) { $app.IsSelected = -not $allSelected }
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
    $controls.SelectAllButton.IsEnabled = $true
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
    $installArguments = if ($item.InstallArguments) {
        @($item.InstallArguments)
    } else {
        @('install','--id',$item.Id,'--exact')
    }
    $installArguments += @(
        '--silent',
        '--accept-package-agreements','--accept-source-agreements','--disable-interactivity'
    )

    try {
        Write-PowerHubLog -Message "Kuruluyor: $($item.Name)" -Color Cyan
        Write-PowerHubLog -Message "Komut: winget $($installArguments -join ' ')" -Color DarkGray
        $script:installProcess = Start-Process -FilePath 'winget.exe' -ArgumentList $installArguments -PassThru -NoNewWindow
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
    $script:installQueue = @($apps | Where-Object IsSelected | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            Id = $_.Id
            Action = if ($_.PSObject.Properties['Action']) { $_.Action } else { 'Winget' }
            Url = if ($_.PSObject.Properties['Url']) { $_.Url } else { $null }
            InstallArguments = if ($_.PSObject.Properties['InstallArguments']) { @($_.InstallArguments) } else { $null }
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

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($winget) {
    Write-PowerHubLog -Message "winget hazır: $($winget.Source)" -Color Green
    $controls.WingetIconBox.Background = New-ColorBrush '#214B35'
    $controls.WingetIcon.Text = '✓'
    $controls.WingetIcon.Foreground = New-ColorBrush '#7EE2A8'
    $controls.WingetStatus.Text = 'winget hazır'
    $controls.WingetStatus.Foreground = [Windows.Media.Brushes]::White
    $controls.WingetDetail.Text = 'Paket yöneticisi çevrimiçi'
    $controls.WingetBadge.Background = New-ColorBrush '#204A32'
    $controls.WingetBadgeText.Text = 'AKTİF'
    $controls.WingetBadgeText.Foreground = New-ColorBrush '#7EE2A8'
} else {
    Write-PowerHubLog -Message 'winget bulunamadı. Microsoft App Installer gerekli.' -Color Red
    $controls.WingetIconBox.Background = New-ColorBrush '#512D32'
    $controls.WingetIcon.Text = '!'
    $controls.WingetIcon.Foreground = New-ColorBrush '#FF9B9B'
    $controls.WingetStatus.Text = 'winget bulunamadı'
    $controls.WingetStatus.Foreground = [Windows.Media.Brushes]::White
    $controls.WingetDetail.Text = 'App Installer gerekli'
    $controls.WingetBadge.Background = New-ColorBrush '#512D32'
    $controls.WingetBadgeText.Text = 'EKSİK'
    $controls.WingetBadgeText.Foreground = New-ColorBrush '#FF9B9B'
    $controls.ActivityText.Text = 'Microsoft App Installer (winget) gerekli.'
}

Update-AppList
Update-SelectionStatus
Set-PowerHubWindowLayout
Write-PowerHubLog -Message 'PowerHub hazır. Kurulum günlükleri bu terminalde gösterilecek.' -Color Cyan
$window.ShowDialog() | Out-Null
