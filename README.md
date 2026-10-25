# Nagram X

> [!NOTE]
> This is a maintained continuation of [risin42/NagramX](https://github.com/risin42/NagramX), which was archived in August 2026. All credit for the original project goes to its authors.

## Downloads

* [GitHub Releases](https://github.com/JArthur02/NagramXX/releases)

The app keeps the package name `nu.gpu.nagram` but is signed with a different key than the original NagramX, so Android cannot update an existing NagramX install in place. Uninstall the original app first (this removes its local data; your chats stay on Telegram's servers).

Archived builds of the original project remain on its [GitHub Releases](https://github.com/risin42/NagramX/releases) and [Telegram channel](https://t.me/NagramX).

## Verify APK

APKs published here use the following Android signing certificate:

* Package name: `nu.gpu.nagram`
* SHA-256: `6C:17:65:C7:00:9F:33:B5:61:00:59:F3:CA:13:43:1E:BD:06:AD:EB:42:AD:D1:09:06:D4:2A:A1:A1:10:1E:ED`

## Compilation Guide

1. Clone the repository with its submodules:

    ```bash
    git clone --recursive --shallow-submodules https://github.com/JArthur02/NagramXX.git NagramXX
    ```

    If you already cloned the repository without submodules, run:

    ```bash
    git submodule update --init --recursive --depth=1
    ```

2. Obtain API credentials (`TELEGRAM_APP_ID` and `TELEGRAM_APP_HASH`) from [Telegram Developer Portal](https://my.telegram.org/auth). Create `local.properties` in the project root with:

   ```properties
   TELEGRAM_APP_ID=<your_telegram_app_id>
   TELEGRAM_APP_HASH=<your_telegram_app_hash>
   ```

3. For APK signing: Place your keystore at `TMessagesProj/release.keystore` (it is git-ignored) and add signing configuration to `local.properties`:

   ```properties
   KEYSTORE_PASS=<your_keystore_password>
   ALIAS_NAME=<your_alias_name>
   ALIAS_PASS=<your_alias_password>
   ```

4. For FCM support: Replace `TMessagesProj/google-services.json` with your own configuration file.

5. Replace project-specific metadata:

    - Set your Google Maps API key in the `com.google.android.maps.v2.API_KEY` meta-data entry in `TMessagesProj/src/main/AndroidManifest.xml`.
    - Set `BaseRemoteHelper.CHANNEL_METADATA_ID` in `TMessagesProj/src/main/java/tw/nekomimi/nekogram/helpers/remote/BaseRemoteHelper.java` to your metadata channel's numeric ID, without the `-100` prefix.

6. Open the project in Android Studio to start building.

## GitHub Actions Build

The workflows can be used from a fork of this repository.

1. Create a `local.properties` file with the following and Base64 encode it (`base64 -w0 local.properties`):

   ```properties
   KEYSTORE_PASS=<your_keystore_password>
   ALIAS_NAME=<your_alias_name>
   ALIAS_PASS=<your_alias_password>
   TELEGRAM_APP_ID=<your_telegram_app_id>
   TELEGRAM_APP_HASH=<your_telegram_app_hash>
   ```

2. Add these repository secrets (Settings → Secrets and variables → Actions):
   - `LOCAL_PROPERTIES`: Base64-encoded content from step 1
   - `RELEASE_KEYSTORE`: Base64-encoded keystore file (`base64 -w0 release.keystore`)

3. Workflows:
   - **Staging build** runs on every push to `dev` and keeps the APKs as workflow artifacts.
   - **Release Build** is started manually from the Actions tab. It builds signed APKs and publishes them as a GitHub Release tagged `v<versionName>-<versionCode>`; the in-app updater reads that tag. Bump `verCode` in `TMessagesProj/build.gradle` before each release. Tick *prerelease* to offer the build only on the beta update channel.

## Acknowledgments

- [AyuGram](https://github.com/AyuGram/AyuGram4A)
- [Cherrygram](https://github.com/arsLan4k1390/Cherrygram)
- [Dr4iv3rNope](https://github.com/Dr4iv3rNope/NotSoAndroidAyuGram)
- [exteraGram](https://github.com/exteraSquad/exteraGram)
- [Nagram](https://github.com/NextAlone/Nagram)
- [Nekogram](https://github.com/Nekogram/Nekogram)
- [OctoGram](https://github.com/OctoGramApp/OctoGram)
