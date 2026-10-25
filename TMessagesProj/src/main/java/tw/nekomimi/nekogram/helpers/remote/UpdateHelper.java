package tw.nekomimi.nekogram.helpers.remote;

import org.json.JSONArray;
import org.json.JSONObject;
import org.telegram.messenger.BuildConfig;
import org.telegram.messenger.FileLog;
import org.telegram.messenger.NotificationCenter;
import org.telegram.messenger.SharedConfig;
import org.telegram.messenger.Utilities;
import org.telegram.tgnet.TLRPC;

import okhttp3.Request;
import tw.nekomimi.nekogram.utils.HttpClient;
import xyz.nextalone.nagram.NaConfig;

/**
 * Checks GitHub Releases for a newer build.
 * <p>
 * Release tags must be {@code v<versionName>-<versionCode>}, e.g. {@code v13.0.3-1262}.
 * Pre-releases are only offered on the beta channel. The update points at the release
 * page, where the user downloads the APK for their ABI.
 */
public class UpdateHelper {

    public static final int UPDATE_OFF = 0;
    public static final int UPDATE_CHANNEL_RELEASE = 1;
    public static final int UPDATE_CHANNEL_BETA = 2;

    public static final String GITHUB_REPO = "JArthur02/NagramXX";
    private static final String RELEASES_API = "https://api.github.com/repos/" + GITHUB_REPO + "/releases?per_page=10";

    public static UpdateHelper getInstance() {
        return InstanceHolder.instance;
    }

    public static void cleanAppUpdate() {
        SharedConfig.pendingAppUpdate = null;
        SharedConfig.saveConfig();
        NotificationCenter.getGlobalInstance().postNotificationName(NotificationCenter.appUpdateAvailable);
    }

    public void checkNewVersionAvailable(BaseRemoteHelper.Delegate delegate) {
        checkNewVersionAvailable(delegate, false);
    }

    public void checkNewVersionAvailable(BaseRemoteHelper.Delegate delegate, boolean updateAlways) {
        Utilities.globalQueue.postRunnable(() -> {
            try {
                delegate.onTLResponse(fetchUpdate(updateAlways), null);
            } catch (Exception e) {
                FileLog.e(e);
                delegate.onTLResponse(null, e.getMessage());
            }
        });
    }

    private TLRPC.TL_help_appUpdate fetchUpdate(boolean updateAlways) throws Exception {
        int channel = NaConfig.INSTANCE.getAutoUpdateChannel().Int();
        if (channel == UPDATE_OFF && !updateAlways) {
            return null;
        }
        var request = new Request.Builder()
                .url(RELEASES_API)
                .header("Accept", "application/vnd.github+json")
                .build();
        String body;
        try (var response = HttpClient.INSTANCE.getInstance().newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new Exception("GitHub HTTP " + response.code());
            }
            body = response.body().string();
        }
        var releases = new JSONArray(body);
        boolean includePrerelease = channel == UPDATE_CHANNEL_BETA || BuildConfig.DEBUG;
        for (int i = 0; i < releases.length(); i++) {
            JSONObject release = releases.getJSONObject(i);
            if (release.optBoolean("draft") || (!includePrerelease && release.optBoolean("prerelease"))) {
                continue;
            }
            int versionCode = parseVersionCode(release.optString("tag_name"));
            if (versionCode <= 0) {
                continue;
            }
            if (versionCode <= BuildConfig.VERSION_CODE && !updateAlways) {
                return null;
            }
            var update = new TLRPC.TL_help_appUpdate();
            update.version = release.optString("name", release.optString("tag_name"));
            update.text = release.optString("body", "");
            update.url = release.getString("html_url");
            update.flags |= 4;
            return update;
        }
        return null;
    }

    private static int parseVersionCode(String tag) {
        int dash = tag.lastIndexOf('-');
        if (dash < 0) {
            return 0;
        }
        try {
            return Integer.parseInt(tag.substring(dash + 1));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private static final class InstanceHolder {
        private static final UpdateHelper instance = new UpdateHelper();
    }
}
