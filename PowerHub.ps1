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

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerHub" Width="1100" Height="730" MinWidth="900" MinHeight="600"
        WindowStartupLocation="CenterScreen" Background="{DynamicResource PageBg}"
        FontFamily="Segoe UI Variable, Segoe UI" TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType" TextOptions.TextHintingMode="Fixed"
        UseLayoutRounding="True" SnapsToDevicePixels="True">
    <Window.Resources>
        <SolidColorBrush x:Key="Primary" Color="#0078D4"/>
        <SolidColorBrush x:Key="Ink" Color="#202124"/>
        <SolidColorBrush x:Key="Muted" Color="#697078"/>
        <SolidColorBrush x:Key="PageBg" Color="#DDE1E5"/>
        <SolidColorBrush x:Key="CardBg" Color="#ECEFF1"/>
        <SolidColorBrush x:Key="CardBorder" Color="#C5CBD1"/>
        <SolidColorBrush x:Key="SoftBg" Color="#D6E4EF"/>
        <SolidColorBrush x:Key="SoftText" Color="#0067B8"/>
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
                            <Border x:Name="CheckBorder" Background="#E5E9EC" BorderBrush="#858D95"
                                    BorderThickness="1.2" CornerRadius="5"/>
                            <Path x:Name="CheckMark" Data="M 4 10 L 8 14 L 16 6" Stroke="White"
                                  StrokeThickness="2" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                  Visibility="Collapsed"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="CheckBorder" Property="BorderBrush" Value="{DynamicResource Primary}"/>
                                <Setter TargetName="CheckBorder" Property="Background" Value="#DCE7EF"/>
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
            <ColumnDefinition Width="230"/>
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
                        <StackPanel Orientation="Horizontal" Margin="0,2,0,0">
                            <TextBlock Text="Uygulama merkezi" Foreground="#9CB1C2" FontSize="10"/>
                            <Border Background="#174C70" CornerRadius="6" Padding="4,1" Margin="6,0,0,0">
                                <TextBlock Text="PRO" Foreground="#7DD3FC" FontSize="7" FontWeight="Bold"/>
                            </Border>
                        </StackPanel>
                    </StackPanel>
                </StackPanel>

                <Grid Grid.Row="1" Margin="8,0,8,8">
                    <TextBlock Text="KATEGORİLER" Foreground="#7F94A6" FontSize="9" FontWeight="Bold"/>
                    <Border Height="1" Background="#485058" Margin="78,6,0,0"/>
                </Grid>
                <StackPanel Grid.Row="2" x:Name="CategoryPanel">
                    <Button Style="{StaticResource NavButton}" Tag="Tümü" Background="#174C70" BorderBrush="#278DD1">
                        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <Border Width="28" Height="28" Background="#087BBE" CornerRadius="8"><TextBlock Text="▦" Foreground="White" FontSize="13" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                            <TextBlock Grid.Column="1" Text="Tüm uygulamalar" Foreground="White" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center"/>
                            <Border Grid.Column="2" Background="#23516C" CornerRadius="8" Padding="6,2" VerticalAlignment="Center"><TextBlock Text="16" Foreground="#BEE7FF" FontSize="8" FontWeight="Bold"/></Border>
                        </Grid>
                    </Button>
                    <Button Style="{StaticResource NavButton}" Tag="Tarayıcı">
                        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <Border Width="28" Height="28" Background="#334D5E" CornerRadius="8"><TextBlock Text="◎" Foreground="#7DD3FC" FontSize="14" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                            <TextBlock Grid.Column="1" Text="Tarayıcılar" Foreground="#E7EDF3" FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock Grid.Column="2" Text="3" Foreground="#8093A2" FontSize="9" VerticalAlignment="Center" Margin="0,0,4,0"/>
                        </Grid>
                    </Button>
                    <Button Style="{StaticResource NavButton}" Tag="İletişim">
                        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <Border Width="28" Height="28" Background="#433C59" CornerRadius="8"><TextBlock Text="✉" Foreground="#C4B5FD" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                            <TextBlock Grid.Column="1" Text="İletişim" Foreground="#E7EDF3" FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock Grid.Column="2" Text="3" Foreground="#8093A2" FontSize="9" VerticalAlignment="Center" Margin="0,0,4,0"/>
                        </Grid>
                    </Button>
                    <Button Style="{StaticResource NavButton}" Tag="Medya">
                        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <Border Width="28" Height="28" Background="#574632" CornerRadius="8"><TextBlock Text="▷" Foreground="#FCD34D" FontSize="13" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                            <TextBlock Grid.Column="1" Text="Medya" Foreground="#E7EDF3" FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock Grid.Column="2" Text="3" Foreground="#8093A2" FontSize="9" VerticalAlignment="Center" Margin="0,0,4,0"/>
                        </Grid>
                    </Button>
                    <Button Style="{StaticResource NavButton}" Tag="Geliştirme">
                        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <Border Width="28" Height="28" Background="#284B47" CornerRadius="8"><TextBlock Text="&lt;/&gt;" Foreground="#6EE7B7" FontSize="9" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                            <TextBlock Grid.Column="1" Text="Geliştirme" Foreground="#E7EDF3" FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock Grid.Column="2" Text="3" Foreground="#8093A2" FontSize="9" VerticalAlignment="Center" Margin="0,0,4,0"/>
                        </Grid>
                    </Button>
                    <Button Style="{StaticResource NavButton}" Tag="Araçlar">
                        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <Border Width="28" Height="28" Background="#3B485A" CornerRadius="8"><TextBlock Text="⚙" Foreground="#93C5FD" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                            <TextBlock Grid.Column="1" Text="Araçlar" Foreground="#E7EDF3" FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock Grid.Column="2" Text="4" Foreground="#8093A2" FontSize="9" VerticalAlignment="Center" Margin="0,0,4,0"/>
                        </Grid>
                    </Button>
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

        <Grid Grid.Column="1" Margin="30,24,30,22">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Border x:Name="HeaderBanner" CornerRadius="18" Padding="20,17" Background="{DynamicResource CardBg}"
                    BorderBrush="{DynamicResource CardBorder}" BorderThickness="1">
                <Border.Effect><DropShadowEffect Color="#626971" BlurRadius="18" ShadowDepth="3" Opacity="0.16"/></Border.Effect>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="58"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="285"/>
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
                        <TextBlock Text="Uygulamalarını seç ve tek seferde kur."
                                   Foreground="{DynamicResource Muted}" FontSize="13" Margin="0,4,0,0"/>
                        <StackPanel Orientation="Horizontal" Margin="0,11,0,0">
                            <Border Background="{DynamicResource SoftBg}" CornerRadius="9" Padding="9,4" Margin="0,0,7,0">
                                <TextBlock Text="16 uygulama" Foreground="{DynamicResource SoftText}" FontSize="10" FontWeight="SemiBold"/>
                            </Border>
                            <Border Background="#E8F6EC" CornerRadius="9" Padding="9,4">
                                <TextBlock Text="●  Sistem hazır" Foreground="#287A45" FontSize="10" FontWeight="SemiBold"/>
                            </Border>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Grid.Column="2" VerticalAlignment="Center">
                        <Border Background="#E3E7EA" BorderBrush="{DynamicResource CardBorder}"
                                BorderThickness="1" CornerRadius="11" Height="42">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="38"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <TextBlock Text="⌕" FontSize="22" Foreground="#697078" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                <TextBox x:Name="SearchBox" Grid.Column="1" BorderThickness="0" Background="Transparent"
                                         VerticalContentAlignment="Center" FontSize="13" Foreground="{DynamicResource Ink}" CaretBrush="{DynamicResource Primary}"
                                         ToolTip="Uygulama ara..." Margin="0,0,8,0"/>
                            </Grid>
                        </Border>
                        <Grid Margin="3,9,3,0">
                            <TextBlock Text="WINGET KATALOĞU" Foreground="{DynamicResource Muted}" FontSize="9" FontWeight="Bold"/>
                            <TextBlock Text="GÜVENLİ • REKLAMSIZ" HorizontalAlignment="Right" Foreground="#287A45" FontSize="9" FontWeight="Bold"/>
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
                <ListBox.ItemsPanel>
                    <ItemsPanelTemplate><WrapPanel IsItemsHost="True"/></ItemsPanelTemplate>
                </ListBox.ItemsPanel>
                <ListBox.ItemContainerStyle>
                    <Style TargetType="ListBoxItem">
                        <Setter Property="Padding" Value="0"/><Setter Property="Margin" Value="0,0,10,8"/>
                        <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                        <Setter Property="Template">
                            <Setter.Value><ControlTemplate TargetType="ListBoxItem"><ContentPresenter/></ControlTemplate></Setter.Value>
                        </Setter>
                    </Style>
                </ListBox.ItemContainerStyle>
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <Border Width="374" Height="70" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1"
                                CornerRadius="11" Padding="0" ClipToBounds="True" SnapsToDevicePixels="True">
                            <Border.Effect><DropShadowEffect Color="#717780" BlurRadius="9" ShadowDepth="1" Opacity="0.16"/></Border.Effect>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="4"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Background="{Binding Color}"/>
                                <Grid Grid.Column="1" Margin="11,7,10,7">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="43"/><ColumnDefinition Width="*"/><ColumnDefinition Width="25"/></Grid.ColumnDefinitions>
                                    <Border Width="36" Height="36" Background="{Binding Color}" CornerRadius="10" VerticalAlignment="Center">
                                        <Border.Effect><DropShadowEffect Color="#687078" BlurRadius="7" ShadowDepth="1" Opacity="0.22"/></Border.Effect>
                                        <TextBlock Text="{Binding Initial}" Foreground="White" FontWeight="Bold" FontSize="14"
                                                   HorizontalAlignment="Center" VerticalAlignment="Center"/>
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
                <Border.Effect><DropShadowEffect Color="#626971" BlurRadius="16" ShadowDepth="2" Opacity="0.16"/></Border.Effect>
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
@('Sidebar','HeaderBanner','CategoryPanel','WingetIconBox','WingetIcon','WingetStatus','WingetDetail','WingetBadge','WingetBadgeText','SearchBox','SectionTitle','ResultCount','AppList','SelectionText',
  'ActivityText','InstallProgress','SelectAllButton','InstallButton') | ForEach-Object {
    $controls[$_] = $window.FindName($_)
}

function New-ColorBrush([string]$color) {
    return [Windows.Media.BrushConverter]::new().ConvertFromString($color)
}

$apps = [Collections.ArrayList]@(
    [pscustomobject]@{ Name='Google Chrome'; Description='Hızlı web tarayıcısı'; Id='Google.Chrome'; Category='Tarayıcı'; Initial='G'; Color='#4285F4'; IsSelected=$false },
    [pscustomobject]@{ Name='Mozilla Firefox'; Description='Özgür ve gizlilik odaklı'; Id='Mozilla.Firefox'; Category='Tarayıcı'; Initial='F'; Color='#FF7139'; IsSelected=$false },
    [pscustomobject]@{ Name='Brave'; Description='Reklam engelleyici tarayıcı'; Id='Brave.Brave'; Category='Tarayıcı'; Initial='B'; Color='#FB542B'; IsSelected=$false },
    [pscustomobject]@{ Name='Discord'; Description='Topluluk ve sesli sohbet'; Id='Discord.Discord'; Category='İletişim'; Initial='D'; Color='#5865F2'; IsSelected=$false },
    [pscustomobject]@{ Name='Telegram'; Description='Hızlı ve güvenli mesajlaşma'; Id='Telegram.TelegramDesktop'; Category='İletişim'; Initial='T'; Color='#229ED9'; IsSelected=$false },
    [pscustomobject]@{ Name='Zoom'; Description='Video toplantıları'; Id='Zoom.Zoom'; Category='İletişim'; Initial='Z'; Color='#2D8CFF'; IsSelected=$false },
    [pscustomobject]@{ Name='VLC'; Description='Her formatı oynatır'; Id='VideoLAN.VLC'; Category='Medya'; Initial='V'; Color='#F59E0B'; IsSelected=$false },
    [pscustomobject]@{ Name='Spotify'; Description='Müzik ve podcast'; Id='Spotify.Spotify'; Category='Medya'; Initial='S'; Color='#1DB954'; IsSelected=$false },
    [pscustomobject]@{ Name='OBS Studio'; Description='Kayıt ve canlı yayın'; Id='OBSProject.OBSStudio'; Category='Medya'; Initial='O'; Color='#4B5563'; IsSelected=$false },
    [pscustomobject]@{ Name='Visual Studio Code'; Description='Modern kod editörü'; Id='Microsoft.VisualStudioCode'; Category='Geliştirme'; Initial='VS'; Color='#007ACC'; IsSelected=$false },
    [pscustomobject]@{ Name='Git'; Description='Sürüm kontrol sistemi'; Id='Git.Git'; Category='Geliştirme'; Initial='G'; Color='#F05032'; IsSelected=$false },
    [pscustomobject]@{ Name='Node.js LTS'; Description='JavaScript çalışma ortamı'; Id='OpenJS.NodeJS.LTS'; Category='Geliştirme'; Initial='N'; Color='#339933'; IsSelected=$false },
    [pscustomobject]@{ Name='7-Zip'; Description='Hafif arşiv yöneticisi'; Id='7zip.7zip'; Category='Araçlar'; Initial='7'; Color='#6B7280'; IsSelected=$false },
    [pscustomobject]@{ Name='PowerToys'; Description='Windows üretkenlik araçları'; Id='Microsoft.PowerToys'; Category='Araçlar'; Initial='P'; Color='#735DD0'; IsSelected=$false },
    [pscustomobject]@{ Name='Everything'; Description='Anında dosya arama'; Id='voidtools.Everything'; Category='Araçlar'; Initial='E'; Color='#F97316'; IsSelected=$false },
    [pscustomobject]@{ Name='Notepad++'; Description='Hızlı metin editörü'; Id='Notepad++.Notepad++'; Category='Araçlar'; Initial='N+'; Color='#73B53E'; IsSelected=$false }
)

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

$controls.InstallButton.Add_Click({
    $queue = @($apps | Where-Object IsSelected | ForEach-Object { [pscustomobject]@{ Name=$_.Name; Id=$_.Id } })
    if ($queue.Count -eq 0) { return }

    $script:isInstalling = $true
    $controls.InstallButton.IsEnabled = $false
    $controls.SelectAllButton.IsEnabled = $false
    $controls.InstallProgress.Visibility = 'Visible'
    $controls.InstallProgress.Value = 0
    $controls.ActivityText.Text = 'Kurulum hazırlanıyor...'

    $worker = New-Object ComponentModel.BackgroundWorker
    $worker.WorkerReportsProgress = $true
    $worker.DoWork += {
        param($sender, $e)
        $items = @($e.Argument)
        $results = [Collections.ArrayList]::new()
        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $sender.ReportProgress([int](($i / $items.Count) * 100), "Kuruluyor: $($item.Name)")
            try {
                $process = Start-Process -FilePath 'winget.exe' -ArgumentList @(
                    'install','--id',$item.Id,'--exact','--silent',
                    '--accept-package-agreements','--accept-source-agreements','--disable-interactivity'
                ) -Wait -PassThru -WindowStyle Hidden
                [void]$results.Add([pscustomobject]@{ Name=$item.Name; Success=($process.ExitCode -eq 0); Code=$process.ExitCode })
            } catch {
                [void]$results.Add([pscustomobject]@{ Name=$item.Name; Success=$false; Code=-1 })
            }
        }
        $e.Result = $results
        $sender.ReportProgress(100, 'Kurulum tamamlandı.')
    }
    $worker.ProgressChanged += {
        param($sender, $e)
        $controls.InstallProgress.Value = $e.ProgressPercentage
        $controls.ActivityText.Text = [string]$e.UserState
    }
    $worker.RunWorkerCompleted += {
        param($sender, $e)
        $script:isInstalling = $false
        $controls.SelectAllButton.IsEnabled = $true
        $controls.InstallButton.IsEnabled = $true
        if ($e.Error) {
            $controls.ActivityText.Text = "Kurulum hatası: $($e.Error.Message)"
            [Windows.MessageBox]::Show($window, $e.Error.Message, 'PowerHub', 'OK', 'Error') | Out-Null
        } else {
            $failed = @($e.Result | Where-Object { -not $_.Success })
            $successCount = @($e.Result | Where-Object Success).Count
            if ($failed.Count -eq 0) {
                $controls.ActivityText.Text = "$successCount uygulama başarıyla kuruldu."
                [Windows.MessageBox]::Show($window, 'Seçilen tüm uygulamalar başarıyla kuruldu.', 'PowerHub', 'OK', 'Information') | Out-Null
            } else {
                $controls.ActivityText.Text = "$successCount başarılı, $($failed.Count) başarısız."
                $failedText = ($failed | ForEach-Object { "• $($_.Name) (kod: $($_.Code))" }) -join "`n"
                [Windows.MessageBox]::Show($window, "Bazı kurulumlar tamamlanamadı:`n`n$failedText", 'PowerHub', 'OK', 'Warning') | Out-Null
            }
        }
        Update-SelectionStatus
    }
    $worker.RunWorkerAsync($queue)
})

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($winget) {
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
$window.ShowDialog() | Out-Null
