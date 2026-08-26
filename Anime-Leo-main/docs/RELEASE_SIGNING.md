# Release signing — Anime Leo

Android updates require the **same application ID and the same signing key**. The release workflow now expects one persistent keystore stored in GitHub Secrets.

## One-time setup from Termux

Create a release keystore (choose your own password and alias):

```bash
keytool -genkeypair -v \
  -keystore anime-leo-release.jks \
  -alias animeleo \
  -keyalg RSA -keysize 2048 -validity 10000
```

Convert it to Base64:

```bash
base64 -w 0 anime-leo-release.jks > anime-leo-release.jks.b64
```

Add these GitHub repository secrets:

- `ANIME_LEO_KEYSTORE_BASE64` — the contents of `anime-leo-release.jks.b64`
- `ANIME_LEO_KEYSTORE_PASSWORD` — keystore password
- `ANIME_LEO_KEY_ALIAS` — `animeleo` (or the alias you selected)
- `ANIME_LEO_KEY_PASSWORD` — key password

**Never commit the `.jks`, `.b64`, or `key.properties` files.**

## Important migration note

The previous workflow generated Android files on the GitHub runner and did not persist a release keystore. If the currently installed APK was signed by that temporary key, Android cannot accept the new persistent-key APK as an in-place update. A one-time uninstall/reinstall may therefore still be required for the first APK built with this signing setup.

After that first persistent-key release, future releases with a higher `versionCode` will install as normal updates and keep `SharedPreferences` data such as favorites and watch history.
