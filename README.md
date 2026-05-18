<p align="center">
  <img src="Sources/Droppie/Resources/AppIcon.png" alt="Droppie icon" width="96" height="96">
</p>

<h1 align="center">Droppie</h1>

<p align="center">
  <strong>Paste, drop, upload.</strong>
</p>

<p align="center">
  Native macOS menu bar app for turning files and clipboard content into public links.
</p>

## Install

Download `Droppie-0.1.0.zip` from [Releases](../../releases), unzip it, and move `Droppie.app` to `/Applications` or `~/Applications`.

Requires macOS 14+. The current public build is Apple Silicon only and is not notarized.

## Use

- Press `Command-V` in the popover to upload clipboard content.
- Drop files onto the open popover or the closed menu bar icon.
- Select files from Finder.
- Copy links automatically after upload.
- Keep recent uploads in local history.

## Providers

- here.now
- Imgur
- Amazon S3
- Cloudflare R2
- Google Drive
- Dropbox
- S3-compatible storage

Provider settings live locally. Secrets are stored in macOS Keychain.

## Build

```bash
git clone https://github.com/vyctorbrzezowski/droppie.git
cd droppie
swift test
./script/install.sh
open ~/Applications/Droppie.app
```

## License

[MIT](LICENSE)
