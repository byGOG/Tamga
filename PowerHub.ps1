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
        Title="PowerHub" Width="980" Height="900" MinWidth="860" MinHeight="700"
        WindowStartupLocation="Manual" Background="{DynamicResource PageBg}"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="12" TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType" TextOptions.TextHintingMode="Fixed"
        UseLayoutRounding="True" SnapsToDevicePixels="True">
    <Window.Resources>
        <SolidColorBrush x:Key="Primary" Color="#0078D4"/>
        <SolidColorBrush x:Key="Ink" Color="#F7F9FA"/>
        <SolidColorBrush x:Key="Muted" Color="#BCC5CE"/>
        <SolidColorBrush x:Key="PageBg" Color="#252A30"/>
        <SolidColorBrush x:Key="CardBg" Color="#30363D"/>
        <SolidColorBrush x:Key="CardBorder" Color="#454D56"/>
        <SolidColorBrush x:Key="SoftBg" Color="#263F52"/>
        <SolidColorBrush x:Key="SoftText" Color="#82CEFF"/>
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
                                                <Border Background="#596572" CornerRadius="5" Margin="3,1"/>
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
            <ColumnDefinition Width="245"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Border x:Name="Sidebar" Grid.Column="0" BorderThickness="0">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                    <GradientStop Color="#24272B" Offset="0"/>
                    <GradientStop Color="#35393E" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
            <Grid Margin="20,24">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <StackPanel Orientation="Horizontal" Margin="8,0,0,25">
                    <Border Width="44" Height="44" CornerRadius="13">
                        <Border.Background>
                            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                <GradientStop Color="#0EA5E9" Offset="0"/>
                                <GradientStop Color="#0067C0" Offset="1"/>
                            </LinearGradientBrush>
                        </Border.Background>
                        <Border.Effect><DropShadowEffect Color="#071A29" BlurRadius="14" ShadowDepth="3" Opacity="0.48"/></Border.Effect>
                        <TextBlock Text="P" Foreground="White" FontSize="21" FontWeight="Bold"
                                   HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Margin="11,0,0,0">
                        <TextBlock Text="PowerHub" Foreground="White" FontWeight="Bold" FontSize="19"/>
                        <TextBlock Text="Uygulama merkezi" Foreground="#AEC0CF" FontSize="11.5" Margin="0,3,0,0"/>
                    </StackPanel>
                </StackPanel>

                <Grid Grid.Row="1" Margin="8,0,8,8">
                    <TextBlock Text="KATEGORİLER" Foreground="#9AAEBD" FontSize="10.5" FontWeight="Bold"/>
                    <Border Height="1" Background="#485058" Margin="78,6,0,0"/>
                </Grid>
                <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Margin="0,0,0,8">
                    <ScrollViewer.Resources><Style TargetType="ScrollBar" BasedOn="{StaticResource SlimScrollBar}"/></ScrollViewer.Resources>
                    <StackPanel x:Name="CategoryPanel"/>
                </ScrollViewer>

                <Border x:Name="WingetCard" Grid.Row="3" Background="#2B3035" BorderBrush="#46515A" BorderThickness="1"
                        CornerRadius="15" Padding="11" Margin="0,10,0,0" ToolTip="winget durumunu ve kurulum motorunu gösterir">
                    <Border.Effect><DropShadowEffect Color="#11161A" BlurRadius="10" ShadowDepth="1" Opacity="0.24"/></Border.Effect>
                    <Grid>
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="38"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name="WingetIconBox" Width="30" Height="30" Background="#214B35" BorderBrush="#346A4D" BorderThickness="1" CornerRadius="10">
                            <TextBlock x:Name="WingetIcon" Text="✓" Foreground="#7EE2A8" FontSize="14" FontWeight="Bold"
                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <TextBlock x:Name="WingetStatus" Grid.Column="1" Text="winget kontrol ediliyor" Foreground="White"
                                   FontSize="12.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
                        <Border x:Name="WingetBadge" Grid.Column="2" Background="#204A32" BorderBrush="#346A4D" BorderThickness="1"
                                CornerRadius="9" Padding="7,4" VerticalAlignment="Center">
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

        <Grid Grid.Column="1" Margin="26,22,26,20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Border x:Name="HeaderBanner" CornerRadius="18" Padding="22,19" Background="{DynamicResource CardBg}"
                    BorderBrush="{DynamicResource CardBorder}" BorderThickness="1">
                <Border.Effect><DropShadowEffect Color="#0E1114" BlurRadius="18" ShadowDepth="3" Opacity="0.30"/></Border.Effect>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="64"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="260"/>
                    </Grid.ColumnDefinitions>
                    <Border Width="50" Height="50" Background="{DynamicResource Primary}" CornerRadius="15"
                            VerticalAlignment="Top" HorizontalAlignment="Left">
                        <Border.Effect><DropShadowEffect Color="#0078D4" BlurRadius="12" ShadowDepth="2" Opacity="0.30"/></Border.Effect>
                        <Grid>
                            <Rectangle Width="21" Height="17" Fill="Transparent" Stroke="White" StrokeThickness="1.8" RadiusX="3" RadiusY="3"/>
                            <Path Data="M 15 17 L 23 17 M 19 13 L 19 21" Stroke="White" StrokeThickness="1.8"
                                  StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                        </Grid>
                    </Border>
                    <StackPanel Grid.Column="1">
                        <TextBlock Text="Paket merkezi" FontSize="28" FontWeight="Bold" Foreground="{DynamicResource Ink}"/>
                        <TextBlock Text="Seç, kur ve devam et."
                                   Foreground="{DynamicResource Muted}" FontSize="14" Margin="0,5,0,0"/>
                        <StackPanel Orientation="Horizontal" Margin="0,11,0,0">
                            <Border Background="{DynamicResource SoftBg}" CornerRadius="9" Padding="9,4" Margin="0,0,7,0">
                                <TextBlock x:Name="TotalAppBadgeText" Text="0 uygulama" Foreground="{DynamicResource SoftText}" FontSize="11" FontWeight="SemiBold"/>
                            </Border>
                            <Border Background="#203B2C" CornerRadius="9" Padding="9,4">
                                <TextBlock Text="●  Sistem hazır" Foreground="#7EE2A8" FontSize="11" FontWeight="SemiBold"/>
                            </Border>
                            <Border Background="#343A45" CornerRadius="9" Padding="9,4" Margin="7,0,0,0">
                                <TextBlock x:Name="CategoryBadgeText" Text="0 kategori" Foreground="#C5D1DC" FontSize="11" FontWeight="SemiBold"/>
                            </Border>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Grid.Column="2" VerticalAlignment="Center">
                        <Border Background="#292F35" BorderBrush="{DynamicResource CardBorder}"
                                BorderThickness="1" CornerRadius="11" Height="46">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="38"/><ColumnDefinition Width="*"/><ColumnDefinition Width="34"/></Grid.ColumnDefinitions>
                                <TextBlock Text="⌕" FontSize="22" Foreground="#AAB3BC" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                <TextBlock x:Name="SearchPlaceholder" Grid.Column="1" Text="Uygulama veya kaynak ara..." Foreground="#7F8A95"
                                           FontSize="13" VerticalAlignment="Center" IsHitTestVisible="False"/>
                                <TextBox x:Name="SearchBox" Grid.Column="1" BorderThickness="0" Background="Transparent"
                                         VerticalContentAlignment="Center" FontSize="14" Foreground="{DynamicResource Ink}" CaretBrush="{DynamicResource Primary}"
                                         ToolTip="Uygulama ara..." Margin="0,0,8,0"/>
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

            <Grid Grid.Row="1" Margin="0,18,0,12">
                <TextBlock x:Name="SectionTitle" Text="Tüm uygulamalar" FontSize="17" FontWeight="SemiBold" Foreground="{DynamicResource Ink}"/>
                <TextBlock x:Name="ResultCount" HorizontalAlignment="Right" Foreground="{StaticResource Muted}" FontSize="13"/>
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
                        <Setter Property="Padding" Value="0"/><Setter Property="Margin" Value="0,0,0,10"/>
                        <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                        <Setter Property="Template">
                            <Setter.Value><ControlTemplate TargetType="ListBoxItem"><ContentPresenter/></ControlTemplate></Setter.Value>
                        </Setter>
                    </Style>
                </ListBox.ItemContainerStyle>
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <Border x:Name="CardBorder" Height="82" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1"
                                CornerRadius="11" Padding="0" ClipToBounds="True" SnapsToDevicePixels="True">
                            <Border.Effect><DropShadowEffect Color="#101419" BlurRadius="9" ShadowDepth="1" Opacity="0.28"/></Border.Effect>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="4"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border x:Name="AccentBar" Background="{Binding Color}"/>
                                <Grid Grid.Column="1" Margin="14,9,13,9">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="52"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="34"/></Grid.ColumnDefinitions>
                                    <Border Width="44" Height="44" Background="{Binding Color}" CornerRadius="12" VerticalAlignment="Center">
                                        <Border.Effect><DropShadowEffect Color="#687078" BlurRadius="7" ShadowDepth="1" Opacity="0.22"/></Border.Effect>
                                        <Grid>
                                            <Image Source="{Binding Logo}" Width="34" Height="34" Stretch="Uniform"
                                                   HorizontalAlignment="Center" VerticalAlignment="Center" SnapsToDevicePixels="True"/>
                                            <TextBlock Text="{Binding Initial}" Opacity="{Binding InitialOpacity}" Foreground="White" FontWeight="Bold" FontSize="15"
                                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>
                                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,8,0">
                                        <TextBlock Text="{Binding Name}" Foreground="{DynamicResource Ink}" FontWeight="SemiBold" FontSize="15"
                                                   TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Text="{Binding Description}" Foreground="{DynamicResource Muted}" FontSize="12" Margin="0,4,0,0"
                                                   TextTrimming="CharacterEllipsis"/>
                                    </StackPanel>
                                    <Border Grid.Column="2" Background="{Binding SourceBackground}" CornerRadius="8" Padding="8,4" Margin="8,0,10,0"
                                            VerticalAlignment="Center" ToolTip="Kurulum kaynağı">
                                        <TextBlock Text="{Binding SourceLabel}" Foreground="{Binding SourceForeground}" FontSize="9.5" FontWeight="Bold"/>
                                    </Border>
                                    <CheckBox x:Name="AppCheck" Grid.Column="3" IsChecked="{Binding IsSelected, Mode=TwoWay}"
                                              VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                </Grid>
                            </Grid>
                        </Border>
                        <DataTemplate.Triggers>
                            <DataTrigger Binding="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=ListBoxItem}}" Value="True">
                                <Setter TargetName="CardBorder" Property="Background" Value="#363E47"/>
                                <Setter TargetName="CardBorder" Property="BorderBrush" Value="#5A6876"/>
                            </DataTrigger>
                            <DataTrigger Binding="{Binding IsChecked, ElementName=AppCheck}" Value="True">
                                <Setter TargetName="CardBorder" Property="Background" Value="#293F50"/>
                                <Setter TargetName="CardBorder" Property="BorderBrush" Value="#278DD1"/>
                                <Setter TargetName="CardBorder" Property="BorderThickness" Value="1.5"/>
                            </DataTrigger>
                        </DataTemplate.Triggers>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>

            <Border Grid.Row="3" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1" CornerRadius="13"
                    Padding="16,12" Margin="0,8,0,0">
                <Border.Effect><DropShadowEffect Color="#0E1114" BlurRadius="16" ShadowDepth="2" Opacity="0.28"/></Border.Effect>
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock x:Name="SelectionText" Text="Henüz uygulama seçilmedi" Foreground="{DynamicResource Ink}" FontSize="14" FontWeight="SemiBold"/>
                        <TextBlock x:Name="ActivityText" Text="Kurulacak uygulamaları işaretleyin." Foreground="{DynamicResource Muted}" FontSize="12" Margin="0,4,0,0"/>
                        <ProgressBar x:Name="InstallProgress" Height="4" Margin="0,8,18,0" Minimum="0" Maximum="100"
                                     Value="0" Visibility="Collapsed" Foreground="{DynamicResource Primary}" Background="{DynamicResource SoftBg}"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <Button x:Name="SelectAllButton" Content="Görünenleri seç" Background="{DynamicResource SoftBg}" Foreground="{DynamicResource SoftText}"
                                Margin="0,0,9,0" ToolTip="Görünen kartları seç veya seçimi kaldır (Ctrl+A)"/>
                        <Button x:Name="InstallButton" Content="Kurulumu başlat  →" Background="{DynamicResource Primary}" Foreground="White"
                                IsEnabled="False" ToolTip="Seçilenleri kur (Enter)"/>
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
@('Sidebar','HeaderBanner','CategoryPanel','WingetCard','WingetIconBox','WingetIcon','WingetStatus','WingetDetail','WingetBadge','WingetBadgeDot','WingetBadgeText','TotalAppBadgeText','CategoryBadgeText','SearchBox','SearchPlaceholder','SearchClearButton','SectionTitle','ResultCount','AppList','SelectionText',
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

foreach ($app in $apps) {
    if (-not $app.PSObject.Properties['Logo']) {
        $app | Add-Member -NotePropertyName Logo -NotePropertyValue $null
    }
    if (-not $app.PSObject.Properties['InitialOpacity']) {
        $app | Add-Member -NotePropertyName InitialOpacity -NotePropertyValue 1.0
    }
    $isWebResource = $app.PSObject.Properties['Action'] -and $app.Action -eq 'Url'
    $app | Add-Member -NotePropertyName SourceLabel -NotePropertyValue $(if ($isWebResource) { 'WEB' } else { 'WINGET' }) -Force
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
    [pscustomobject]@{ Name='Tümü'; Display='Tüm uygulamalar'; Icon='▦'; Background='#087BBE'; Foreground='#FFFFFF' },
    [pscustomobject]@{ Name='Web Tarayıcıları'; Display='Web Tarayıcıları'; Icon='◎'; Background='#334D5E'; Foreground='#7DD3FC' },
    [pscustomobject]@{ Name='Eklentiler'; Display='Eklentiler'; Icon='+'; Background='#4B465D'; Foreground='#D8C7FF' },
    [pscustomobject]@{ Name='İletişim & Sosyal'; Display='İletişim & Sosyal'; Icon='✉'; Background='#433C59'; Foreground='#C4B5FD' },
    [pscustomobject]@{ Name='Üretkenlik'; Display='Üretkenlik'; Icon='◆'; Background='#3D5258'; Foreground='#9ED5D8' },
    [pscustomobject]@{ Name='Multimedya'; Display='Multimedya'; Icon='▷'; Background='#574632'; Foreground='#FCD34D' },
    [pscustomobject]@{ Name='Geliştirme'; Display='Geliştirme'; Icon='</>'; Background='#284B47'; Foreground='#6EE7B7' },
    [pscustomobject]@{ Name='Yapay Zeka'; Display='Yapay Zeka'; Icon='✦'; Background='#51405E'; Foreground='#D8B4FE' },
    [pscustomobject]@{ Name='Donanım & Test'; Display='Donanım & Test'; Icon='◫'; Background='#55473D'; Foreground='#F5C59B' },
    [pscustomobject]@{ Name='Ağ & Uzaktan Erişim'; Display='Ağ & Uzaktan Erişim'; Icon='⌁'; Background='#34545B'; Foreground='#8FE3E8' },
    [pscustomobject]@{ Name='Mobil & Araçlar'; Display='Mobil & Araçlar'; Icon='▯'; Background='#42536A'; Foreground='#A9CCF4' },
    [pscustomobject]@{ Name='Sistem Araçları'; Display='Sistem Araçları'; Icon='⚙'; Background='#3B485A'; Foreground='#93C5FD' },
    [pscustomobject]@{ Name='Güvenlik'; Display='Güvenlik'; Icon='◇'; Background='#563C43'; Foreground='#FDA4AF' },
    [pscustomobject]@{ Name='Gizlilik & Ağ Ayarları'; Display='Gizlilik & Ağ Ayarları'; Icon='◇'; Background='#34545B'; Foreground='#8FE3E8' },
    [pscustomobject]@{ Name='Oyun & Platformlar'; Display='Oyun & Platformlar'; Icon='◈'; Background='#40533B'; Foreground='#B7E39B' },
    [pscustomobject]@{ Name='Dosya Yönetimi'; Display='Dosya Yönetimi'; Icon='▤'; Background='#56503D'; Foreground='#E8D897' },
    [pscustomobject]@{ Name='Sanallaştırma'; Display='Sanallaştırma'; Icon='⬡'; Background='#444A68'; Foreground='#B8C2FF' },
    [pscustomobject]@{ Name='İndirme Yöneticileri'; Display='İndirme Yöneticileri'; Icon='↓'; Background='#3E526A'; Foreground='#A8D3F5' },
    [pscustomobject]@{ Name='Film & Medya'; Display='Film & Medya'; Icon='▶'; Background='#55455E'; Foreground='#E2B5EF' },
    [pscustomobject]@{ Name='Uygulama Arşivleri'; Display='Uygulama Arşivleri'; Icon='▦'; Background='#4D543D'; Foreground='#D5E5A2' },
    [pscustomobject]@{ Name='Test & Web Analiz'; Display='Test & Web Analiz'; Icon='◉'; Background='#3E5360'; Foreground='#A9D8E8' },
    [pscustomobject]@{ Name='Betikler & Otomasyon'; Display='Betikler & Otomasyon'; Icon='⚡'; Background='#55435B'; Foreground='#E8B8F3' }
)

foreach ($category in $categoryDefinitions) {
    $count = if ($category.Name -eq 'Tümü') { $apps.Count } else { @($apps | Where-Object Category -eq $category.Name).Count }
    $button = [Windows.Controls.Button]::new()
    $button.Style = $window.Resources['NavButton']
    $button.Tag = $category.Name
    $button.ToolTip = $category.Display
    $button.Margin = [Windows.Thickness]::new(0,2,0,2)
    $button.Padding = [Windows.Thickness]::new(9,6,9,6)
    if ($category.Name -eq 'Tümü') {
        $button.Background = New-ColorBrush '#174C70'
        $button.BorderBrush = New-ColorBrush '#278DD1'
    }

    $grid = [Windows.Controls.Grid]::new()
    $grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $grid.ColumnDefinitions[0].Width = [Windows.GridLength]::new(38)
    $grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $grid.ColumnDefinitions[1].Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $grid.ColumnDefinitions[2].Width = [Windows.GridLength]::Auto

    $iconBox = [Windows.Controls.Border]::new()
    $iconBox.Width = 30
    $iconBox.Height = 30
    $iconBox.CornerRadius = [Windows.CornerRadius]::new(9)
    $iconBox.Background = New-ColorBrush $category.Background
    $icon = [Windows.Controls.TextBlock]::new()
    $icon.Text = $category.Icon
    $icon.Foreground = New-ColorBrush $category.Foreground
    $icon.FontSize = if ($category.Icon -eq '</>') { 9.5 } else { 13 }
    $icon.FontWeight = [Windows.FontWeights]::SemiBold
    $icon.HorizontalAlignment = 'Center'
    $icon.VerticalAlignment = 'Center'
    $iconBox.Child = $icon

    $label = [Windows.Controls.TextBlock]::new()
    $label.Text = $category.Display
    $label.Foreground = New-ColorBrush '#E7EDF3'
    $label.FontSize = 11.5
    $label.FontWeight = if ($category.Name -eq 'Tümü') { [Windows.FontWeights]::SemiBold } else { [Windows.FontWeights]::Normal }
    $label.VerticalAlignment = 'Center'
    $label.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
    [Windows.Controls.Grid]::SetColumn($label, 1)

    $countText = [Windows.Controls.TextBlock]::new()
    $countText.Text = [string]$count
    $countText.Foreground = New-ColorBrush '#AFC0CE'
    $countText.FontSize = 10
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
$controls.CategoryBadgeText.Text = "{0} kategori" -f ($categoryDefinitions.Count - 1)

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

function Update-SearchChrome {
    $hasSearch = -not [string]::IsNullOrWhiteSpace($controls.SearchBox.Text)
    $controls.SearchPlaceholder.Visibility = if ($hasSearch) { 'Collapsed' } else { 'Visible' }
    $controls.SearchClearButton.Visibility = if ($hasSearch) { 'Visible' } else { 'Collapsed' }
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

$controls.SearchBox.Add_TextChanged({
    Update-SearchChrome
    Update-AppList
})
$controls.SearchClearButton.Add_Click({
    $controls.SearchBox.Clear()
    $controls.SearchBox.Focus() | Out-Null
})
$controls.AppList.AddHandler([Windows.Controls.CheckBox]::CheckedEvent, [Windows.RoutedEventHandler]{ Update-SelectionStatus })
$controls.AppList.AddHandler([Windows.Controls.CheckBox]::UncheckedEvent, [Windows.RoutedEventHandler]{ Update-SelectionStatus })
$controls.AppList.Add_PreviewMouseLeftButtonUp({
    param($sender, $eventArgs)

    $source = $eventArgs.OriginalSource
    $node = $source
    while ($node) {
        if ($node -is [Windows.Controls.CheckBox]) { return }
        try { $node = [Windows.Media.VisualTreeHelper]::GetParent($node) } catch { $node = $null }
    }

    $container = [Windows.Controls.ItemsControl]::ContainerFromElement($controls.AppList, $source)
    if (-not $container) { return }
    $checkBox = Find-VisualChild -Parent $container -ChildType ([Windows.Controls.CheckBox])
    if ($checkBox) {
        $checkBox.IsChecked = -not [bool]$checkBox.IsChecked
        $eventArgs.Handled = $true
    }
})

$window.Add_PreviewKeyDown({
    param($sender, $eventArgs)

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
        foreach ($app in $script:visibleApps) { $app.IsSelected = $true }
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

function Set-WingetCardState {
    param([ValidateSet('Ready','Missing','Installing','Store')][string]$State)

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
        'Store' {
            $script:wingetReady = $false
            $controls.WingetCard.Cursor = [Windows.Input.Cursors]::Hand
            $controls.WingetCard.BorderBrush = New-ColorBrush '#B07A38'
            $controls.WingetIconBox.Background = New-ColorBrush '#594523'
            $controls.WingetIconBox.BorderBrush = New-ColorBrush '#8A682F'
            $controls.WingetIcon.Text = '↗'
            $controls.WingetIcon.Foreground = New-ColorBrush '#FFD58A'
            $controls.WingetStatus.Text = 'App Installer gerekli'
            $controls.WingetDetail.Text = 'Microsoft Store sayfasını açmak için tıklayın'
            $controls.WingetBadge.Background = New-ColorBrush '#58441F'
            $controls.WingetBadge.BorderBrush = New-ColorBrush '#8A682F'
            $controls.WingetBadgeDot.Fill = New-ColorBrush '#F5BC5A'
            $controls.WingetBadgeText.Text = 'STORE'
            $controls.WingetBadgeText.Foreground = New-ColorBrush '#FFD58A'
        }
    }
    $controls.WingetStatus.Foreground = [Windows.Media.Brushes]::White
}

$script:wingetReady = $false
$script:wingetInstallProcess = $null
$script:wingetInstallTimer = [Windows.Threading.DispatcherTimer]::new()
$script:wingetInstallTimer.Interval = [TimeSpan]::FromMilliseconds(500)

$script:wingetInstallTimer.Add_Tick({
    if (-not $script:wingetInstallProcess) { return }
    $script:wingetInstallProcess.Refresh()
    if (-not $script:wingetInstallProcess.HasExited) { return }

    $script:wingetInstallTimer.Stop()
    $script:wingetInstallProcess.WaitForExit()
    $exitCode = [int]$script:wingetInstallProcess.ExitCode
    $script:wingetInstallProcess.Dispose()
    $script:wingetInstallProcess = $null
    $wingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue

    if ($exitCode -eq 0 -and $wingetCommand) {
        Write-PowerHubLog -Message "winget başarıyla kuruldu: $($wingetCommand.Source)" -Color Green
        $controls.ActivityText.Text = 'winget başarıyla kuruldu. Uygulamalar kurulabilir.'
        Set-WingetCardState -State Ready
        Update-SelectionStatus
    } else {
        Write-PowerHubLog -Message "Otomatik winget kurulumu tamamlanamadı (kod: $exitCode). Microsoft Store açılıyor." -Color Yellow
        $controls.ActivityText.Text = 'Otomatik kurulum tamamlanamadı. Microsoft Store açıldı.'
        Set-WingetCardState -State Store
        Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'
    }
})

$controls.WingetCard.Add_MouseLeftButtonUp({
    if ($script:wingetReady -or $script:wingetInstallProcess) { return }

    Set-WingetCardState -State Installing
    $controls.ActivityText.Text = 'Microsoft App Installer indiriliyor ve winget kuruluyor...'
    Write-PowerHubLog -Message 'winget otomatik kurulumu başlatıldı.' -Color Cyan

    $installerScript = @'
$ErrorActionPreference = 'Stop'
Write-Host '[PowerHub] Microsoft App Installer denetleniyor...' -ForegroundColor Cyan
try {
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    Start-Sleep -Seconds 2
} catch {}
if (Get-Command winget.exe -ErrorAction SilentlyContinue) { exit 0 }
$packagePath = Join-Path $env:TEMP 'Microsoft.DesktopAppInstaller.msixbundle'
Write-Host '[PowerHub] Resmî winget paketi indiriliyor...' -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/getwinget' -OutFile $packagePath
Write-Host '[PowerHub] App Installer kuruluyor...' -ForegroundColor Cyan
Add-AppxPackage -Path $packagePath -ForceApplicationShutdown
Remove-Item -LiteralPath $packagePath -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (Get-Command winget.exe -ErrorAction SilentlyContinue) { exit 0 }
exit 1
'@
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($installerScript))
    try {
        $script:wingetInstallProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
            '-NoProfile','-ExecutionPolicy','Bypass','-OutputFormat','Text','-EncodedCommand',$encodedCommand
        ) -PassThru -NoNewWindow
        $script:wingetInstallTimer.Start()
    } catch {
        Write-PowerHubLog -Message "winget kurulumu başlatılamadı: $($_.Exception.Message)" -Color Red
        $controls.ActivityText.Text = 'Otomatik kurulum başlatılamadı. Microsoft Store açıldı.'
        Set-WingetCardState -State Store
        Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'
    }
})

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($winget) {
    Write-PowerHubLog -Message "winget hazır: $($winget.Source)" -Color Green
    Set-WingetCardState -State Ready
} else {
    Write-PowerHubLog -Message 'winget bulunamadı. Kurulum için durum kartına tıklayın.' -Color Yellow
    Set-WingetCardState -State Missing
    $controls.ActivityText.Text = 'winget kurmak için sol alttaki durum kartına tıklayın.'
}

Update-AppList
Update-SelectionStatus
Set-PowerHubWindowLayout
Write-PowerHubLog -Message 'PowerHub hazır. Kurulum günlükleri bu terminalde gösterilecek.' -Color Cyan
$window.ShowDialog() | Out-Null
