# PowerHub

PowerHub, Windows uygulamalarını seçip `winget` üzerinden toplu ve sessiz biçimde kurmak için hazırlanmış modern bir PowerShell/WPF arayüzüdür.

## Hızlı çalıştırma

PowerShell'e aşağıdaki komutu yapıştırın:

```powershell
irm https://bygog.github.io/PowerHub/i.ps1 | iex
```

Başlatıcı, güncel `PowerHub.ps1` dosyasını `%LOCALAPPDATA%\PowerHub` klasörüne indirir ve Windows PowerShell'i STA modunda kullanarak arayüzü açar. Her çalıştırmada en güncel sürüm alınır.

## Gereksinimler

- Windows 10 veya Windows 11
- Windows PowerShell 5.1
- Microsoft App Installer ile gelen `winget`
- İnternet bağlantısı

## Güvenlik

İnternetten alınan bir betiği çalıştırmadan önce içeriğini incelemek için:

```powershell
irm https://bygog.github.io/PowerHub/i.ps1
```

Ana uygulama dosyası doğrudan şu adresten görüntülenebilir:

```text
https://bygog.github.io/PowerHub/PowerHub.ps1
```

