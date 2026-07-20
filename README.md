<div align="center">

<img src="assets/tamga-logo.png" alt="Tamga logosu" width="112" height="112">

# Tamga

**Windows uygulamalarını tek yerden keşfet, kur, kaldır ve güncelle.**

[![Windows 10 ve 11](https://img.shields.io/badge/Windows-10%20ve%2011-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20ve%207-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![WinGet](https://img.shields.io/badge/WinGet-destekli-00A4EF)](https://learn.microsoft.com/windows/package-manager/winget/)
[![Son güncelleme](https://img.shields.io/github/last-commit/byGOG/Tamga?label=son%20güncelleme&color=18A7E0)](https://github.com/byGOG/Tamga/commits/main)

[Hızlı kurulum](#hızlı-kurulum) · [Nasıl kullanılır?](#nasıl-kullanılır) · [Sorun giderme](#sorun-giderme) · [Sorun bildir](https://github.com/byGOG/Tamga/issues)

</div>

---

## Tamga nedir?

Tamga, Windows uygulamalarını yönetmeyi kolaylaştıran açık kaynak bir masaüstü aracıdır. Uygulamaları tek tek arayıp farklı sitelerden indirmek yerine Tamga içinden:

- uygulama arayabilir ve kategorilere göz atabilirsiniz,
- birden fazla uygulamayı sıraya ekleyip topluca kurabilirsiniz,
- kurulu uygulamaları kaldırabilirsiniz,
- kullanılabilir güncellemeleri tek ekranda görebilirsiniz,
- uygulamaların resmî sitelerine güvenli biçimde ulaşabilirsiniz,
- sistem ve paket yöneticisi durumunu denetleyebilirsiniz.

Tamga şu anda **21 kategoride 146 uygulama ve internet kaynağı** sunar. Kurulabilir paketler WinGet üzerinden yönetilir; yalnızca internet bağlantısı olan kayıtlar kurulum sırasına eklenmez ve doğrudan ilgili siteyi açar.

## Hızlı kurulum

### Önerilen yöntem: tek komut

1. Başlat menüsünü açın.
2. **PowerShell** yazıp uygulamayı çalıştırın.
3. Aşağıdaki komutu yapıştırıp <kbd>Enter</kbd> tuşuna basın:

```powershell
irm https://bygog.github.io/Tamga/install.ps1 | iex
```

Tamga güncel dosyaları `%LOCALAPPDATA%\Tamga` klasörüne indirir ve uygulamayı açar. Daha sonraki çalıştırmalarda aynı komutu kullanabilirsiniz; başlatıcı en güncel sürümü alır.

> [!TIP]
> Uygulama kurulumu veya kaldırılması sırasında Windows yönetici izni isteyebilir. Bu normaldir; Tamga’nın kendisini açmak için sürekli yönetici olarak çalıştırmanız gerekmez.

### BAT dosyasıyla çalıştırma

Komut kullanmak istemiyorsanız [Tamga-Online.bat dosyasını indirin](https://bygog.github.io/Tamga/Tamga-Online.bat) ve çift tıklayın.

> [!IMPORTANT]
> GitHub’daki dosya görüntüleme sayfasına sağ tıklayıp **Farklı kaydet** demeyin. Bu işlem BAT yerine HTML sayfası indirebilir. Yukarıdaki doğrudan indirme bağlantısını kullanın.

PowerShell üzerinden indirmek isterseniz:

```powershell
curl.exe -L "https://bygog.github.io/Tamga/Tamga-Online.bat" -o "$HOME\Downloads\Tamga-Online.bat"
```

İndirilen dosyayı terminalden çalıştırmak için dosyanın başına `./` değil, Windows PowerShell’de `\.\` ekleyin:

```powershell
cd "$HOME\Downloads"
.\Tamga-Online.bat
```

### Depoyu indirerek çalıştırma

```powershell
git clone https://github.com/byGOG/Tamga.git
cd Tamga
.\Tamga.bat
```

Git kullanmıyorsanız GitHub’daki **Code → Download ZIP** seçeneğiyle projeyi indirebilir, arşivi çıkardıktan sonra `Tamga.bat` dosyasına çift tıklayabilirsiniz.

## Nasıl kullanılır?

1. **Kategori seçin veya arama yapın.** Sol menüden kategoriye geçin ya da üstteki arama kutusuna uygulama adını yazın.
2. **Uygulamayı inceleyin.** Bilgi düğmesi ayrıntıları, bağlantı düğmesi resmî siteyi açar.
3. **Kurulacak uygulamaları seçin.** Kartın sağındaki kutuyu işaretleyin. İnternet kaynağı olan kartlar seçilemez; doğrudan siteyi açar.
4. **Kurulumu başlatın.** Alt çubuktaki **Kurulumu başlat** düğmesine basın. İşlem kuyruğunda her paketin durumunu görebilirsiniz.
5. **Güncellemeleri yönetin.** Sol alttaki **Güncelleme Merkezi** tüm bekleyen WinGet güncellemelerini listeler.
6. **Kurulu uygulamayı kaldırın.** Karttaki kırmızı kaldırma düğmesine basın ve onaylayın. Liste işlemden sonra otomatik yenilenir.

### Tamga Reçetesi

Aynı uygulama grubunu başka bir bilgisayarda yeniden seçmek için alt çubuktaki **Reçete** düğmesini kullanın:

- **Seçimi reçete olarak kaydet** seçili WinGet paketlerini taşınabilir bir `.tamga.json` dosyasına yazar.
- **Reçete aç** dosyadaki paketleri katalogda bulup seçer.
- Zaten kurulu, katalogdan kaldırılmış veya bu sistemde kullanılamayan kayıtlar güvenle atlanır.
- Reçete açmak kurulumu kendiliğinden başlatmaz; son onay her zaman kullanıcıdadır.

### Durum etiketleri

| Etiket | Anlamı |
| --- | --- |
| **KURULU** | Uygulama bilgisayarınızda kurulu. |
| **KURULU DEĞİL** | Uygulama kurulabilir durumda. |
| **GÜNCELLEME** | Daha yeni bir sürüm bulunuyor. |
| **SİTE** | Kart bir internet kaynağıdır; kurulum yapmaz. |
| **POWERSHELL** | İlgili aracın resmî PowerShell komutunu çalıştırır. |

## Öne çıkan özellikler

- Windows 10 ve Windows 11 ile uyumlu modern koyu arayüz
- Akıllı kurulu uygulama ve güncelleme taraması
- Toplu kurulum, güncelleme ve kaldırma kuyruğu
- Bilgisayarlar arasında güvenle taşınabilen Tamga Reçeteleri
- Paket sürümü, yayıncı, lisans ve kaynak bilgilerini gösteren ayrıntı çekmecesi
- Windows koruması, WinGet kaynakları ve katalog bütünlüğü için Güvenlik Merkezi
- Eksik WinGet’i Microsoft Store olmadan hazırlayabilen kurulum akışı
- Windows Sandbox gibi boş sistemlerde çalışma desteği
- Resmî site bağlantıları ve yerel önbelleğe alınan uygulama logoları
- Klavye kullanımı, görünür odak halkaları ve ekran okuyucu etiketleri

## Gereksinimler

- Windows 10 veya Windows 11
- Windows PowerShell 5.1 ya da PowerShell 7
- İnternet bağlantısı
- Kurulum yapılacak paketler için yeterli disk alanı
- Bazı uygulamalar için yönetici izni

WinGet sistemde yoksa sol alttaki **WinGet** kartına tıklayın. Tamga gerekli Microsoft bağımlılıklarını ve App Installer paketini hazırlamayı dener.

## Klavye kısayolları

| Kısayol | İşlev |
| --- | --- |
| <kbd>F1</kbd> | Klavye yardımını gösterir. |
| <kbd>F5</kbd> | Geçerli taramayı yeniler. |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> veya <kbd>Ctrl</kbd> + <kbd>K</kbd> | Arama kutusuna gider. |
| <kbd>Ctrl</kbd> + <kbd>A</kbd> | Görünen kurulabilir uygulamaları seçer veya seçimi kaldırır. |
| <kbd>Ctrl</kbd> + <kbd>Enter</kbd> | Seçilen işlemleri başlatır. |
| <kbd>Ctrl</kbd> + <kbd>Q</kbd> | İşlem kuyruğunu açar. |
| <kbd>Ctrl</kbd> + <kbd>R</kbd> | Tamga Reçetesi menüsünü açar. |
| <kbd>Esc</kbd> | Açık pencereyi veya aramayı kapatır. |

## Güvenlik

Tamga açık kaynaklıdır; çalıştırılan komutları terminalde görebilirsiniz.

- WinGet işlemlerinde tam paket kimliği ve `--exact` eşleşmesi kullanılır.
- Kurulabilir paketler mümkün olduğunda `winget` kaynağıyla sınırlandırılır.
- Tamga kalıcı Execution Policy değişikliği yapmaz.
- Tamga kullanıcı yazı tiplerini kurmaz, silmez veya font kayıt defterini değiştirmez.
- Uygulama ve katalog dosyaları GitHub Pages üzerinden indirilir.
- Kaldırma işlemleri açık kullanıcı onayı olmadan başlatılmaz.
- Tamga, Güvenlik Merkezi üzerinden durumu raporlar; Windows güvenlik ayarlarını izinsiz değiştirmez.

Çalıştırmadan önce yükleyiciyi incelemek isterseniz:

```powershell
$kurucu = irm https://bygog.github.io/Tamga/install.ps1
$kurucu
```

İnceledikten sonra çalıştırmak için:

```powershell
$kurucu | iex
```

## Sorun giderme

### `ï»¿#` komut olarak tanınmıyor

Eski bir `Tamga-Online.bat` sürümü kullanıyorsunuz. Dosyayı silip [güncel BAT dosyasını](https://bygog.github.io/Tamga/Tamga-Online.bat) yeniden indirin. Güncel başlatıcı yükleyiciyi metin olarak değil, geçici PowerShell dosyası olarak çalıştırır.

### BAT dosyası `<!DOCTYPE html>` hatası veriyor

İndirdiğiniz dosya gerçek BAT değil, GitHub’ın HTML sayfasıdır. Doğrudan indirmek için:

```powershell
curl.exe -L "https://bygog.github.io/Tamga/Tamga-Online.bat" -o "$HOME\Downloads\Tamga-Online.bat"
```

### PowerShell dosyayı bulamıyor

PowerShell geçerli klasördeki dosyaları yalnızca adını yazarak çalıştırmaz. Başına `.\` ekleyin:

```powershell
.\Tamga-Online.bat
```

### Betik çalıştırma devre dışı

Tamga’yı yalnızca geçerli PowerShell işlemi için izin vererek açabilirsiniz:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "$env:LOCALAPPDATA\Tamga\Tamga.ps1"
```

### WinGet bulunamıyor

Tamga’daki **WinGet** durum kartına tıklayın. Kurulum tamamlandıktan sonra Tamga paket kaynaklarını yeniler ve sistem taramasını tekrarlar.

### Kurulum başarısız oluyor

- İnternet bağlantınızı kontrol edin.
- Terminalde görünen hata metnini inceleyin.
- Microsoft Store kaynağı hata veriyorsa işlemi yeniden deneyin; bazı Store servis hataları geçici olabilir.
- Paketin resmî sitesini karttaki bağlantı düğmesiyle açıp sistem gereksinimlerini kontrol edin.
- Sorun devam ederse hata metni ve ekran görüntüsüyle [bildirim oluşturun](https://github.com/byGOG/Tamga/issues).

## Tamga’yı kaldırma

Tamga taşınabilir yapıda çalışır ve Windows’a ayrı bir kaldırıcı eklemez. Uygulamayı kapattıktan sonra yerel dosyaları silmeniz yeterlidir:

```powershell
Remove-Item "$env:LOCALAPPDATA\Tamga" -Recurse -Force
```

Bu işlem Tamga aracılığıyla kurduğunuz uygulamaları kaldırmaz.

<details>
<summary><strong>Geliştiriciler ve katkıda bulunmak isteyenler</strong></summary>

### Temel dosyalar

| Dosya | Görevi |
| --- | --- |
| `Tamga.ps1` | WPF arayüzü ve paket işlem motoru |
| `catalog.json` | Uygulamalar, kategoriler, paket kimlikleri ve resmî siteler |
| `logos.json` | Katalogdaki uygulama logo verileri |
| `install.ps1` | Güncel dosyaları yerel Tamga klasörüne indiren başlatıcı |
| `Tamga.bat` | Yerel PowerShell betiğini çift tıklamayla açan başlatıcı |
| `Tamga-Online.bat` | Güncel çevrim içi yükleyiciyi indirip çalıştıran başlatıcı |
| `tools/Test-Tamga.ps1` | PowerShell, XAML, katalog, bağlantı, varlık ve güvenlik sınırı denetimleri |

Katalog değişikliklerinde `SchemaVersion`, benzersiz uygulama adları ve geçerli kategori adları korunmalıdır. Kod değişikliklerinde Windows PowerShell 5.1 uyumluluğu gözetilmelidir.

Yerel kalite kapısını çalıştırmak için:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Tamga.ps1
```

Aynı denetimler her gönderim ve çekme isteğinde yalıtılmış bir Windows GitHub Actions ortamında otomatik çalışır. Denetim uygulamayı açmaz, paket kurmaz ve sistem ayarlarını değiştirmez.

Katkı, hata raporu ve uygulama önerileri için [GitHub Issues](https://github.com/byGOG/Tamga/issues) sayfasını kullanabilirsiniz.

</details>

---

<div align="center">

Tamga, [byGOG](https://bygog.github.io/) tarafından geliştirilmektedir.

*Sordum.net topluluğunun paylaşım kültürü ve kullanıcı odaklı vizyonundan ilham alınarak hazırlandı.*

[Sordum.net](https://www.sordum.net/) · [GitHub](https://github.com/byGOG/Tamga) · [İnternet sitesi](https://bygog.github.io/)

</div>
