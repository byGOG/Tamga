<div align="center">

# PowerHub

**Windows uygulamalarını keşfet, denetle, toplu kur ve güncel tut.**

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![WinGet](https://img.shields.io/badge/WinGet-powered-00A4EF)](https://learn.microsoft.com/windows/package-manager/winget/)
[![Last commit](https://img.shields.io/github/last-commit/byGOG/PowerHub?color=18A7E0)](https://github.com/byGOG/PowerHub/commits/main)
[![Repo size](https://img.shields.io/github/repo-size/byGOG/PowerHub?color=765DE8)](https://github.com/byGOG/PowerHub)

[Türkçe](#türkçe) · [English](#english) · [Web sitesi](https://bygog.github.io/) · [Sorun bildir](https://github.com/byGOG/PowerHub/issues)

</div>

![PowerHub uygulama önizlemesi](assets/powerhub-preview.png)

---

## Türkçe

PowerHub, Windows uygulamalarını tek merkezden yönetmek için geliştirilmiş açık kaynak bir PowerShell/WPF arayüzüdür. WinGet kataloğunu modern bir masaüstü deneyimiyle birleştirir; uygulama keşfi, kurulum, sistem taraması ve güncelleme işlemlerini sadeleştirir.

### Hızlı başlangıç

PowerShell'i açın ve şu komutu çalıştırın:

```powershell
irm https://bygog.github.io/PowerHub/install.ps1 | iex
```

Başlatıcı en güncel `PowerHub.ps1` dosyasını `%LOCALAPPDATA%\PowerHub` dizinine indirir ve uygulamayı STA modunda açar. Sisteminizde WinGet yoksa PowerHub durum kartı üzerinden Microsoft Store gerektirmeyen kurulumu başlatabilir.

> [!IMPORTANT]
> İnternetten indirilen betikleri çalıştırmadan önce incelemek iyi bir güvenlik alışkanlığıdır. Aşağıdaki [Güvenlik](#güvenlik) bölümüne bakın.

### Öne çıkanlar

| Alan | PowerHub ne sunuyor? |
| --- | --- |
| **Modern arayüz** | Windows 11 ve Fluent tasarım diline uyumlu, net ve erişilebilir koyu WPF arayüzü |
| **Uygulama kataloğu** | 21 kategoride 132 uygulama ve güvenilir web kaynağı |
| **Akıllı sistem taraması** | Kurulu uygulamaları ve bekleyen WinGet güncellemelerini arka planda denetleme |
| **Güncelleme Merkezi** | Sürüm karşılaştırması, tekli veya toplu seçim ve canlı güncelleme ilerlemesi |
| **Birleşik işlem kuyruğu** | Kurulum, güncelleme ve kaldırma için paket bazlı canlı durum, güvenli iptal ve başarısızları yeniden deneme |
| **Güvenli kaldırma** | Kurulu WinGet uygulamalarını kart üzerindeki kaldırma düğmesi, açık onay ve otomatik yeniden tarama ile kaldırma |
| **Uygulama detay çekmecesi** | Logo, açıklama, durum, kurulu/katalog sürümü, yayıncı, geliştirici, lisans, kurucu türü, etiketler ve bağlama uygun hızlı işlemler |
| **Resmî kaynaklar** | Uygulama kartından resmî siteye doğrudan erişim; web kaynaklarını kurulumdan ayırma |
| **Sandbox desteği** | Boş Windows Sandbox ortamında WinGet ve gerekli bağımlılıkları hazırlama |
| **Marka logoları** | Önbelleğe alınan uygulama logoları ve ağ sorunu durumunda güvenli yedek görünüm |

### Nasıl çalışır?

1. PowerHub açılışta WinGet durumunu ve kurulu paketleri denetler.
2. Arama veya kategori menüsüyle istediğiniz uygulamaya odaklanırsınız.
3. Uygulamaları seçer, resmî sitelerini açar, toplu kurulum başlatır veya kurulu paketleri karttan kaldırırsınız.
4. Güncelleme Merkezi, mevcut ve yeni sürümleri karşılaştırarak seçili paketleri yükseltir.
5. Tüm komutlar ve sonuçlar görünür terminal günlüğüne yazılır.

### Klavye kısayolları

| Kısayol | İşlev |
| --- | --- |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> | Arama alanına odaklan |
| <kbd>Ctrl</kbd> + <kbd>A</kbd> | Görünen kurulabilir uygulamaları seç / seçimi kaldır |
| <kbd>Enter</kbd> | Seçilen uygulamaların kurulumunu başlat |
| <kbd>Esc</kbd> | Aramayı, seçimi veya açık pencereyi temizle |

### Kurulum seçenekleri

#### Tek komutla

```powershell
irm https://bygog.github.io/PowerHub/install.ps1 | iex
```

#### Önce inceleyerek

```powershell
$installer = irm https://bygog.github.io/PowerHub/install.ps1
$installer
```

İçeriği inceledikten sonra:

```powershell
$installer | iex
```

#### Elle çalıştırma

```powershell
git clone https://github.com/byGOG/PowerHub.git
cd PowerHub
powershell -NoProfile -ExecutionPolicy Bypass -File .\PowerHub.ps1
```

### Gereksinimler

- Windows 10 veya Windows 11
- Windows PowerShell 5.1 ya da PowerShell 7
- İnternet bağlantısı
- Paket kurulumları için yönetici izni gerekebilir
- WinGet önerilir; eksikse PowerHub içinden Store bağımsız kurulum yapılabilir

### Güvenlik

- Kurulum komutları paket kimliğini tam eşleştiren `--exact` seçeneğini kullanır.
- Paket ve kaynak sözleşmeleri WinGet üzerinden açık biçimde kabul edilir.
- WinGet bağımlılıkları resmî Microsoft/GitHub kaynaklarından alınır ve desteklenen dosyalarda SHA-256 doğrulaması uygulanır.
- PowerHub kalıcı Execution Policy değişikliği yapmaz; başlatıcı yalnızca kendi süreç kapsamını kullanır.
- Kurulum günlükleri terminalde görünür; başarısız paketler ayrıca raporlanır.

Ana uygulama dosyasını doğrudan inceleyebilirsiniz:

```text
https://bygog.github.io/PowerHub/PowerHub.ps1
```

### Proje yapısı

```text
PowerHub/
├─ PowerHub.ps1          # WPF arayüzü, katalog ve kurulum motoru
├─ install.ps1           # Hafif çevrimiçi başlatıcı
├─ logos.json            # Uygulama logo kataloğu
├─ assets/               # README görselleri
└─ .nojekyll             # GitHub Pages yapılandırması
```

### Katkıda bulunma

Hata raporu, uygulama önerisi veya geliştirme fikri için [issue açabilirsiniz](https://github.com/byGOG/PowerHub/issues). Değişiklik göndermeden önce mevcut işlevleri koruduğunuzdan ve PowerShell 5.1 uyumluluğunu bozmadığınızdan emin olun.

---

## English

PowerHub is an open-source PowerShell/WPF interface for managing Windows applications from one place. It combines the WinGet catalog with a modern desktop experience and streamlines discovery, installation, system scanning, and package updates.

### Quick start

Open PowerShell and run:

```powershell
irm https://bygog.github.io/PowerHub/install.ps1 | iex
```

The bootstrapper downloads the latest `PowerHub.ps1` to `%LOCALAPPDATA%\PowerHub` and launches it in STA mode. If WinGet is unavailable, PowerHub can install its Store-independent dependencies from the status card.

> [!IMPORTANT]
> Review remote scripts before executing them. See the [Security](#security) section for an inspection-first workflow.

### Highlights

| Area | What PowerHub provides |
| --- | --- |
| **Modern interface** | A clear, accessible dark WPF interface inspired by Windows 11 and Fluent design |
| **Application catalog** | 132 applications and trusted web resources across 21 categories |
| **Smart system scan** | Background detection of installed applications and pending WinGet updates |
| **Update Center** | Version comparison, individual or bulk selection, and live update progress |
| **Unified operation queue** | Per-package live status, safe cancellation, and failed-item retry for installs, upgrades, and removals |
| **Safe uninstall** | Remove installed WinGet applications from their cards with explicit confirmation and automatic rescanning |
| **Application detail drawer** | View branding, status, installed/catalog versions, publisher, author, license, installer type, tags, official site, and context-aware actions |
| **Official sources** | Direct access to official sites while keeping web resources out of install queues |
| **Sandbox support** | Store-independent WinGet and dependency setup for clean Windows Sandbox sessions |
| **Brand assets** | Cached application logos with a safe fallback when the network is unavailable |

### Workflow

1. PowerHub checks WinGet, installed packages, and available updates on startup.
2. Search or category navigation focuses the catalog on what you need.
3. Select applications, open official websites, or start a bulk installation.
4. Update Center compares installed and available versions and upgrades selected packages.
5. Commands and results remain visible in the terminal log.

### Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> | Focus search |
| <kbd>Ctrl</kbd> + <kbd>A</kbd> | Toggle all visible installable applications |
| <kbd>Enter</kbd> | Install selected applications |
| <kbd>Esc</kbd> | Clear search, selection, or the open dialog |

### Installation options

#### One command

```powershell
irm https://bygog.github.io/PowerHub/install.ps1 | iex
```

#### Inspect first

```powershell
$installer = irm https://bygog.github.io/PowerHub/install.ps1
$installer
```

After reviewing the content:

```powershell
$installer | iex
```

#### Manual launch

```powershell
git clone https://github.com/byGOG/PowerHub.git
cd PowerHub
powershell -NoProfile -ExecutionPolicy Bypass -File .\PowerHub.ps1
```

### Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7
- Internet access
- Administrator approval may be required for package installation
- WinGet is recommended; PowerHub can provision it without Microsoft Store when missing

### Security

- Installation commands use `--exact` package matching.
- Package and source agreements are explicitly handled through WinGet.
- WinGet dependencies come from official Microsoft/GitHub sources, with SHA-256 verification where supported.
- PowerHub does not make a permanent Execution Policy change; the launcher uses process scope only.
- Terminal logs remain visible and failed packages are reported separately.

Inspect the main application directly:

```text
https://bygog.github.io/PowerHub/PowerHub.ps1
```

### Project structure

```text
PowerHub/
├─ PowerHub.ps1          # WPF interface, catalog, and installation engine
├─ install.ps1           # Lightweight online bootstrapper
├─ logos.json            # Application logo catalog
├─ assets/               # README media
└─ .nojekyll             # GitHub Pages configuration
```

### Contributing

Use [GitHub Issues](https://github.com/byGOG/PowerHub/issues) for bug reports, application requests, and improvement ideas. Please preserve existing behavior and Windows PowerShell 5.1 compatibility when proposing changes.

---

<div align="center">

PowerHub is maintained by [byGOG](https://bygog.github.io/).

*Sordum.net topluluğunun paylaşım kültürü ve kullanıcı odaklı vizyonundan ilham alınarak hazırlandı.*

[Sordum.net](https://www.sordum.net/) · [GitHub](https://github.com/byGOG/PowerHub) · [Website](https://bygog.github.io/)

</div>
