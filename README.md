# PowerHub

[Türkçe](#türkçe) · [English](#english)

<p align="center">
  <img src="assets/powerhub-preview.png" alt="PowerHub application preview" width="100%">
</p>

## Türkçe

PowerHub, Windows uygulamalarını seçip `winget` üzerinden toplu ve sessiz biçimde kurmak için hazırlanmış modern bir PowerShell/WPF arayüzüdür.

### Hızlı çalıştırma

PowerShell'e aşağıdaki komutu yapıştırın:

```powershell
irm https://bygog.github.io/PowerHub/install.ps1 | iex
```

Başlatıcı, güncel `PowerHub.ps1` dosyasını `%LOCALAPPDATA%\PowerHub` klasörüne indirir ve Windows PowerShell'i STA modunda kullanarak arayüzü açar. Her çalıştırmada en güncel sürüm alınır.

### Gereksinimler

- Windows 10 veya Windows 11
- Windows PowerShell 5.1 ya da PowerShell 7
- Microsoft App Installer ile gelen `winget`
- İnternet bağlantısı

### Güvenlik

İnternetten alınan bir betiği çalıştırmadan önce içeriğini incelemek için:

```powershell
irm https://bygog.github.io/PowerHub/install.ps1
```

Ana uygulama dosyasını doğrudan görüntülemek için:

```text
https://bygog.github.io/PowerHub/PowerHub.ps1
```

---

## English

PowerHub is a modern PowerShell/WPF interface for selecting and silently installing multiple Windows applications through `winget`.

### Quick start

Paste the following command into PowerShell:

```powershell
irm https://bygog.github.io/PowerHub/install.ps1 | iex
```

The bootstrapper downloads the latest `PowerHub.ps1` to `%LOCALAPPDATA%\PowerHub` and launches the interface with Windows PowerShell in STA mode. It retrieves the latest version on every run.

### Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7
- `winget`, included with Microsoft App Installer
- An internet connection

### Security

To inspect the remote bootstrapper before running it:

```powershell
irm https://bygog.github.io/PowerHub/install.ps1
```

To view the main application script directly:

```text
https://bygog.github.io/PowerHub/PowerHub.ps1
```
