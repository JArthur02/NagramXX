# Proposal: Reviving NagramXX on top of Telegram 13.0.3

Status: **draft for review** · Analysed: 2026-10-25

## 1. Where things stand

| | NagramXX (`dev`, `2db685af`) | Upstream `DrKLO/Telegram` (`master`, `0aae9598`) |
|---|---|---|
| Telegram base | 12.10.0 (7031), synced 2026-08-22 | 13.0.3 (7183), released 2026-10-20 |
| MTProto layer | 229 | 231 |
| Last activity | 2026-08-23, "mark project as archived" | active (7 releases since our base) |
| Media stack | in-tree `com.google.android.exoplayer2` | AndroidX **Media3**, as the `TMessagesProj_Modules/media` submodule |
| Native deps | built from source in CI (nasm + ccache) | mostly **prebuilt static libs** in `jni/prebuild`, plus 11 new submodules |
| Build tooling | AGP 9.3.1, Gradle 9.7.1, compileSdk 37, minSdk 27 | AGP 8.13.2, Gradle 8.13, compileSdk 36, minSdk 23 |

The fork's own code is concentrated and mostly separable:

- 212 added Java files (+50.7k lines). Most are in `tw/nekomimi/nekogram` (166) and `com/radolyn/ayugram` (27).
- 543 upstream Java files changed (+23k / −6k lines). These are the hooks into the upstream code.

The fork tracks upstream with snapshot commits ("update to X.Y.Z"), not git merges. The upstream `update to 12.10.0 (7031)` commit (`4e1a61ec`) therefore works as an exact merge base.

### Why it matters

- Every month on 12.10.0 widens the API-layer gap. Newer message, media and gift types fall back to "unsupported", and upstream bug and security fixes are missed. Since our base there are 42 upstream commits, 12 of them merged community fixes for login, sharing, calls and video.
- Some of the fork's infrastructure still points at the archived project:
  - In-app update checks and emoji packs read from channel `2477822904`.
  - The About page links to `risin42/NagramX` and `@NagramX`.
  - CI installs `git+https://github.com/risin42/pyrogram`, an unpinned dependency owned by a third party. That is a supply-chain risk.
  - `release.yml` triggers on `main`, but this repo's default branch is `dev` and it has no `main` branch.

## 2. Trial merge results

I ran `git merge-tree --merge-base=4e1a61ec HEAD 0aae9598`. It is a dry run and changed nothing in the repo.

- **Upstream diff 12.10.0 → 13.0.3:** 422 Java files, +62.6k / −6.9k lines. This excludes the ExoPlayer tree, which upstream removed. Most of the change is new upstream features: the TON wallet (`ui/Wallet/*`), a new round-video/audio recorder, and the Media3 migration.
- **Overlap with fork changes:** 214 files. **125 of them merge cleanly.**
- **Conflicts:** 89 files.

| Kind | Files | Effort | Resolution |
|---|---|---|---|
| Content conflicts in Java | 38 (54 hunks) | Low–medium | Hand-merge. Most files have 1 hunk; the largest have 2–4 (`PeerColorActivity`, `SettingsActivity`, `ConnectionsManager`). |
| Build files (`build.gradle` ×2, `settings.gradle`, `gradle.properties`, wrapper, `buildSrc`, `proguard`, `.gitmodules`) | 8 (14 hunks) | **Medium–high** | Keep the fork's newer toolchain. Add upstream's Media3 modules, `jlatexmath` project and new `buildSrc` plugin (see §3.2). |
| Native (`tgnet/Defines.h`, `voip/...Instance.cpp`) | 2 (2 hunks) | Low | Hand-merge. |
| `README.md` | 1 (1 hunk) | Trivial | Keep the fork's README. |
| Upstream app variants the fork already deleted (`TMessagesProj_App*`, tests, `Dockerfile`, TL codegen) | 25 | Trivial | Keep them deleted. |
| Fork patches to files upstream **removed or moved** | 15 | **Medium** | Port them; see §3.1. |

The full conflict list is in the appendix.

## 3. The hard parts

### 3.1 Fork patches that need a new home

1. **ExoPlayer → Media3** (8 small patches, about 35 lines total, in `BaseRenderer`, `NoSampleRenderer`, `Player`, `FfmpegLibrary`, `WavExtractor`, `MediaCodecInfo`, `MimeTypes`, `UnknownNull`).
   - Re-apply them inside the Media3 submodule. That requires forking `Arseny271/media`, or carrying a patch that a Gradle task applies. Some patches may already be unnecessary under Media3; check each one before porting.
   - Port `tw/nekomimi/nekogram/streaming/MediaStreamingProvider.java` (the only fork-only file that uses `exoplayer2`) to `androidx.media3.*` imports.
   - Fork-modified upstream files that touch the player get the Media3 API through the merge: `VideoPlayer`, `MusicBrowserService`, `TelegramMediaSession`, `MediaController`.
2. **tgcalls moved to a submodule** (`TelegramMessenger/tgcalls`). The fork adds a `customAudioBitrate` knob to `GroupInstanceCustomImpl` (+45 lines). Options: carry a small tgcalls fork, apply a patch at build time, or drop the feature.
3. **`CodeHighlighting.java` was removed** because upstream switched to native `libprisma`. Check whether the fork's 38-line change still matters, then drop or port it.
4. **`VoIPController.java` was removed upstream.** The fork change only redirects call log paths to the cache directory. Re-apply it wherever upstream moved the logic, or drop it.
5. **`buildSrc` lottie-meta plugin was replaced** by `TelegramBuildPlugin`, which also generates string-resource-ID assets and `LocalizationUtils`. Adopt upstream's plugin. Then confirm the fork's NekoX/Ayu string resources still resolve through `LocaleController` (`LocaleController` and `ApplicationLoader` are both conflicted files).

### 3.2 Build system reconciliation

Upstream now expects several things:

- `settings.gradle` must include the Media3 modules (`apply from: TMessagesProj_Modules/media/core_settings.gradle`) and `:jlatexmath`.
- 11 new submodules: `td`, `tgcalls`, `boringssl`, `absl`, `libyuv`, `openh264`, `wamr`, `wallet-engine`, `boost-regex`, `libprisma`, and `media`.
- Prebuilt `.a` libraries under `jni/prebuild/lib/<abi>/`. These would let CI drop the `nasm` and ccache native builds, which cuts build time considerably.

Recommendation: keep the fork's newer AGP 9 / Gradle 9 / compileSdk 37 / Java 21 toolchain and fit upstream's module layout into it. Expect some AGP 9 DSL fixes in the Media3 module build scripts, because upstream builds them with AGP 8.

## 4. Proposed plan

### Phase 0 — Take ownership (small, can land first)

- [ ] **New `applicationId`** (e.g. `nu.gpu.nagramxx`) and a **new signing key**. Official NagramX users can't upgrade in place without the original key, so a distinct ID lets both apps be installed side by side and avoids confusing install failures.
- [ ] Point `BaseRemoteHelper.CHANNEL_METADATA_ID` at a channel we control, or turn off the in-app updater until one exists.
- [ ] Update About-page links, `SessionCell` app-name detection, and the `Tools/scripts/upload.py` default URL.
- [ ] CI: point `release.yml` at a branch that exists. Pin the `pyrogram` dependency to a reviewed commit, or switch to an actively maintained package.
- [ ] Replace `google-services.json` with our own Firebase project, or build without FCM and rely on the existing UnifiedPush support.
- [ ] README: replace the archive banner with a "maintained continuation of risin42/NagramX" note that credits the original.

### Phase 1 — Sync to upstream 13.0.3

1. Add the remote: `git remote add upstream https://github.com/DrKLO/Telegram`.
2. On a branch `sync/13.0.3`, merge the upstream `0aae9598` tree using `4e1a61ec` as base. That is the same three-way merge as the dry run above.
3. Resolve in this order: build files → Java content conflicts → §3.1 ports.
4. Get a debug `arm64-v8a` build green with `pr.yml`.
5. Smoke-test on a device:
   - login (including 2FA and email code)
   - chats, media playback, video and round messages
   - voice and group calls (bitrate setting)
   - fork features: deleted-message saving, translator, streaming, ghost mode, and other Ayu features

### Phase 2 — Release

- [ ] Staging build from `dev`, then canary testers, then release.
- [ ] Bump `verCode` in `TMessagesProj/build.gradle` (currently `1261`).

### Phase 3 — Stay current

- [ ] A scheduled workflow that checks `DrKLO/Telegram` for new `update to X.Y.Z` commits and opens a tracking issue.
- [ ] Merge upstream within about 2 weeks of each release. Small, frequent syncs keep conflicts at the 1–2-hunk level seen here.
- [ ] Write down the merge-base convention (upstream snapshot commit per sync) in `CONTRIBUTING.md`.

## 5. Decisions needed from the maintainer

1. **Package name and signing:** use a new `applicationId` (recommended) or keep `nu.gpu.nagram`?
2. **Push notifications:** use our own Firebase project, or UnifiedPush only?
3. **Upstream's new TON wallet:** ship it, or hide it behind a toggle like other upstream features the fork disables?
4. **Group-call bitrate feature:** maintain a tgcalls patch, or drop it?
5. **Distribution:** GitHub Releases only, or also a Telegram channel (which the Phase 0 updater change needs)?

## Appendix — Conflicts from the trial merge

`C` = content conflict (hunk count). `MD` = modified on one side, deleted on the other.

```
C(5) TMessagesProj/build.gradle
C(4) TMessagesProj/src/main/java/org/telegram/ui/PeerColorActivity.java
C(3) TMessagesProj/src/main/java/org/telegram/ui/SettingsActivity.java
C(3) TMessagesProj/src/main/java/org/telegram/tgnet/ConnectionsManager.java
C(3) TMessagesProj/proguard-rules.pro
C(2) ui/LoginActivity, ui/LaunchActivity, ui/DialogsActivity, ui/ChatActivity,
     ui/Components/TranscribeButton, ui/Components/FilterTabsView,
     messenger/TelegramQRCodeWriter, messenger/LocaleController, messenger/ImageLoader
C(1) settings.gradle, build.gradle, gradle.properties, gradle-wrapper.properties,
     buildSrc/build.gradle.kts, .gitmodules, README.md,
     jni/tgnet/Defines.h, jni/voip/org_telegram_messenger_voip_Instance.cpp,
     ui/TwoStepVerificationSetupActivity, ui/MainTabsActivity, ui/Stories/UploadingDotsSpannable,
     ui/Components/{SpoilersTextView, VideoPlayer, RLottieDrawable, PasscodeView, ItemOptions,
                    ChatAvatarContainer, ChatAttachAlert, ChatActivityEnterView},
     ui/Cells/{ChatMessageCell, ChatActionCell}, ui/ActionBar/{BaseFragment, ActionBar},
     tgnet/TLParseException, messenger/voip/{VoipAudioManager, VoIPPreNotificationService},
     messenger/{UserObject, TelegramMediaSession, SharedConfig, MusicBrowserService,
                MediaController, FileLog, Emoji, ApplicationLoader}

MD (fork-modified, removed upstream — needs porting, §3.1)
     exoplayer2/{BaseRenderer, NoSampleRenderer, Player, ext/ffmpeg/FfmpegLibrary,
                 extractor/wav/WavExtractor, mediacodec/MediaCodecInfo, util/MimeTypes, util/UnknownNull}
     jni/voip/tgcalls/group/GroupInstanceCustomImpl.{cpp,h}
     messenger/CodeHighlighting, messenger/voip/VoIPController
     buildSrc/.../lottie/{LottieMetaExtension, LottieMetaPlugin, LottieMetaTask}

MD (upstream-modified, already deleted by fork — keep deleted)
     Dockerfile, TMessagesProj_App*/**, TMessagesProj_AppTests/**,
     buildSrc/.../com/example/GenerateSchemeTask.kt, buildSrc/.../tlrpc/models/Rules.kt
```

To reproduce:

```bash
git fetch --shallow-since=2026-06-01 https://github.com/DrKLO/Telegram master:refs/remotes/upstream/master
git -c merge.renameLimit=20000 merge-tree --write-tree --name-only \
    --merge-base=4e1a61eca HEAD upstream/master
```
