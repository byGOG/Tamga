<div align="center">

<img src="assets/powerhub-logo.png" alt="PowerHub logosu" width="120" height="120">

# PowerHub

**Windows uygulamalarını keşfet, denetle, toplu kur ve güncel tut.**

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![WinGet](https://img.shields.io/badge/WinGet-destekli-00A4EF)](https://learn.microsoft.com/windows/package-manager/winget/)
[![Son değişiklik](https://img.shields.io/github/last-commit/byGOG/PowerHub?label=son%20değişiklik&color=18A7E0)](https://github.com/byGOG/PowerHub/commits/main)
[![Depo boyutu](https://img.shields.io/github/repo-size/byGOG/PowerHub?label=depo%20boyutu&color=765DE8)](https://github.com/byGOG/PowerHub)

[İnternet sitesi](https://bygog.github.io/) · [Sorun bildir](https://github.com/byGOG/PowerHub/issues)

</div>

---

## Genel bakış

PowerHub, Windows uygulamalarını tek merkezden yönetmek için geliştirilmiş açık kaynak bir PowerShell/WPF arayüzüdür. WinGet kataloğunu modern bir masaüstü deneyimiyle birleştirir; uygulama keşfi, kurulum, sistem taraması ve güncelleme işlemlerini sadeleştirir.

### Hızlı başlangıç

PowerShell'i açın ve şu komutu çalıştırın:

```powershell
irm https://bygog.github.io/PowerHub/install.ps1 | iex
```

Başlatıcı en güncel `PowerHub.ps1` ve `catalog.json` dosyalarını `%LOCALAPPDATA%\PowerHub` dizinine indirir, kataloğu doğrular ve uygulamayı STA modunda açar. Sisteminizde WinGet yoksa PowerHub durum kartı üzerinden Microsoft Mağazası gerektirmeyen kurulumu başlatabilir.

> [!IMPORTANT]
> İnternetten indirilen betikleri çalıştırmadan önce incelemek iyi bir güvenlik alışkanlığıdır. Aşağıdaki [Güvenlik](#güvenlik) bölümüne bakın.

### Öne çıkanlar

| Alan | PowerHub ne sunuyor? |
| --- | --- |
| **Fluent Aurora arayüzü** | Windows 11'in Mica uyumlu katmanları, yumuşak yükselti, modern köşe geometrisi ve sakin camgöbeği vurgularıyla net ve erişilebilir koyu WPF arayüzü |
| **Uygulama kataloğu** | 21 kategoride 132 uygulama ve güvenilir internet kaynağı |
| **Akıllı sistem taraması** | Kurulu uygulamaları ve bekleyen WinGet güncellemelerini arka planda denetleme |
| **Güncelleme Merkezi** | Sürüm karşılaştırması, tekli veya toplu seçim ve canlı güncelleme ilerlemesi |
| **Güvenlik Merkezi** | Windows koruması, WinGet kaynakları, yetki kapsamı, betik çalıştırma ilkesi, katalog bütünlüğü ve bekleyen güncellemeler için puanlı denetim |
| **Birleşik işlem kuyruğu** | Kurulum, güncelleme ve kaldırma için paket bazlı canlı durum, güvenli iptal ve başarısızları yeniden deneme |
| **Güvenli kaldırma** | Kurulu WinGet uygulamalarını kart üzerindeki kaldırma düğmesi, açık onay ve otomatik yeniden tarama ile kaldırma |
| **Uygulama detay çekmecesi** | Logo, açıklama, durum, sürümler, yayıncı, kaynak deposu, kurucu türü, SHA-256 doğrulama durumu, yetki kapsamı, katalog tarihi ve bağlama uygun hızlı işlemler |
| **Resmî kaynaklar** | Uygulama kartından resmî siteye doğrudan erişim; internet kaynaklarını kurulumdan ayırma |
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
| <kbd>F1</kbd> | Klavye ve erişilebilirlik yardımını aç / kapat |
| <kbd>F6</kbd> / <kbd>Shift</kbd> + <kbd>F6</kbd> | Ana arayüz bölgeleri arasında ileri / geri geç |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> veya <kbd>Ctrl</kbd> + <kbd>K</kbd> | Arama alanına odaklan |
| <kbd>Enter</kbd> | Arama kutusundaki sorguyu yeni terminalde WinGet ile ara |
| <kbd>Ctrl</kbd> + <kbd>A</kbd> | Görünen kurulabilir uygulamaları seç / seçimi kaldır |
| <kbd>Ctrl</kbd> + <kbd>Enter</kbd> | Seçilen paket işlemlerini başlat |
| <kbd>Ctrl</kbd> + <kbd>Q</kbd> | Kurulum kuyruğunu aç |
| <kbd>Boşluk</kbd> / <kbd>Enter</kbd> | Odaktaki uygulamayı seç / ayrıntılarını aç |
| <kbd>F5</kbd> | Geçerli sistem veya güvenlik taramasını yenile |
| <kbd>Esc</kbd> | Aramayı veya açık pencereyi kapat |

PowerHub ayrıca görünür klavye odak halkaları, modal odak kilidi ve geri dönüşü, ekran okuyucu etiketleri ve canlı durum duyuruları sunar.

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
```

Ardından `PowerHub.bat` dosyasına çift tıklayın. Terminalden başlatmak için:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PowerHub.ps1
```

Proje dosyalarına ihtiyaç duymadan internet üzerinden en güncel sürümü çalıştırmak için `PowerHub-Online.bat` dosyasını kullanabilirsiniz.

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
- PowerHub kalıcı betik çalıştırma ilkesi değişikliği yapmaz; başlatıcı yalnızca kendi süreç kapsamını kullanır.
- Kurulum günlükleri terminalde görünür; başarısız paketler ayrıca raporlanır.

Ana uygulama dosyasını doğrudan inceleyebilirsiniz:

```text
https://bygog.github.io/PowerHub/PowerHub.ps1
```

### Proje yapısı

```text
PowerHub/
├─ PowerHub-Online.bat   # İnternetten güncel sürümü indirip çalıştırır
├─ PowerHub.bat          # Çift tıklamayla güvenli başlatıcı
├─ PowerHub.ps1          # WPF arayüzü ve paket işlem motoru
├─ catalog.json          # Uygulamalar, kategoriler ve resmî site adresleri
├─ install.ps1           # Kodu ve kataloğu doğrulayarak indiren başlatıcı
├─ logos.json            # Uygulama logo varlıkları
├─ assets/               # README görselleri
└─ .nojekyll             # GitHub Pages yapılandırması
```

### Katkıda bulunma

Hata raporu, uygulama önerisi veya geliştirme fikri için [GitHub üzerinden bildirim oluşturabilirsiniz](https://github.com/byGOG/PowerHub/issues). Kataloğa uygulama eklemek veya bir bağlantıyı düzeltmek için yalnızca `catalog.json` dosyasını düzenleyebilirsiniz; `SchemaVersion`, benzersiz uygulama adları ve geçerli kategori adları korunmalıdır. Kod değişikliklerinde mevcut işlevleri ve Windows PowerShell 5.1 uyumluluğunu koruyun.

---

<div align="center">

PowerHub, [byGOG](https://bygog.github.io/) tarafından geliştirilmektedir.

*Sordum.net topluluğunun paylaşım kültürü ve kullanıcı odaklı vizyonundan ilham alınarak hazırlandı.*

[Sordum.net](https://www.sordum.net/) · [GitHub](https://github.com/byGOG/PowerHub) · [İnternet sitesi](https://bygog.github.io/)

</div>
