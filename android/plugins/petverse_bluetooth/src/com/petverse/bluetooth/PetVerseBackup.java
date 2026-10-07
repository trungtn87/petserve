package com.petverse.bluetooth;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONObject;
import java.io.*;

/** Android document picker: local storage or any installed cloud document provider. */
public final class PetVerseBackup extends GodotPlugin {
    private static final int EXPORT = 28421, IMPORT = 28422;
    private static final long MAX_SIZE = 128L * 1024 * 1024;
    private volatile String pendingPath = "", result = "";
    private volatile boolean busy = false;
    public PetVerseBackup(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "PetVerseBackup"; }
    @UsedByGodot public boolean is_busy() { return busy; }
    @UsedByGodot public synchronized String take_result() { String r = result; result = ""; return r; }
    @UsedByGodot public boolean export_file(String path, String name) { return picker(path, name, EXPORT); }
    @UsedByGodot public boolean import_file(String path) { return picker(path, "", IMPORT); }

    /** Saves a PNG into Pictures/PetVerse using scoped-storage MediaStore on Android 10+. */
    @UsedByGodot public String save_image_to_gallery(String path, String name) {
        Activity activity = getActivity();
        if (activity == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return "";
        File source = new File(path);
        if (!source.isFile()) return "";
        String safeName = (name == null ? "PetVerse_Final.png" : name)
            .replace("/", "_").replace("\\", "_");
        if (!safeName.toLowerCase().endsWith(".png")) safeName += ".png";

        ContentResolver resolver = activity.getContentResolver();
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, safeName);
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
        values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/PetVerse");
        values.put(MediaStore.Images.Media.IS_PENDING, 1);

        Uri uri = null;
        try {
            uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
            if (uri == null) return "";
            try (InputStream input = new FileInputStream(source);
                 OutputStream output = resolver.openOutputStream(uri, "w")) {
                if (output == null) throw new IOException("No gallery output stream");
                copy(input, output);
            }
            ContentValues ready = new ContentValues();
            ready.put(MediaStore.Images.Media.IS_PENDING, 0);
            resolver.update(uri, ready, null, null);
            return uri.toString();
        } catch (Exception e) {
            if (uri != null) {
                try { resolver.delete(uri, null, null); } catch (Exception ignored) {}
            }
            return "";
        }
    }
    private synchronized boolean picker(String path, String name, int request) {
        Activity activity = getActivity();
        if (busy || activity == null || !new File(path).isAbsolute()) return false;
        busy = true; pendingPath = path; result = "";
        activity.runOnUiThread(() -> {
            try {
                Intent intent = new Intent(request == EXPORT ? Intent.ACTION_CREATE_DOCUMENT : Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType(request == EXPORT ? "application/octet-stream" : "*/*");
                if (request == EXPORT) intent.putExtra(Intent.EXTRA_TITLE, name);
                activity.startActivityForResult(intent, request);
            } catch (Exception e) { finish(false, false, "Không mở được trình chọn file Android.", ""); }
        });
        return true;
    }
    @Override public void onMainActivityResult(int request, int code, Intent data) {
        if (request != EXPORT && request != IMPORT) return;
        if (!busy) return;
        if (code != Activity.RESULT_OK || data == null || data.getData() == null) {
            finish(false, true, "Đã hủy.", ""); return;
        }
        final Uri uri = data.getData();
        final String path = pendingPath;
        Thread worker = new Thread(() -> {
            File partial = new File(path + ".transfer");
            Activity activity = getActivity();
            if (activity == null) { finish(false, false, "Không truy cập được file.", ""); return; }
            try {
                if (request == EXPORT) {
                    try (InputStream input = new FileInputStream(path);
                         OutputStream output = activity.getContentResolver().openOutputStream(uri, "wt")) {
                        if (output == null) throw new IOException("No stream");
                        copy(input, output);
                    }
                    finish(true, false, "Đã xuất bản sao lưu.", path);
                } else {
                    partial.getParentFile().mkdirs();
                    try (InputStream input = activity.getContentResolver().openInputStream(uri);
                         OutputStream output = new FileOutputStream(partial)) {
                        if (input == null) throw new IOException("No stream");
                        copy(input, output);
                    }
                    if (!partial.renameTo(new File(path))) throw new IOException("Rename failed");
                    finish(true, false, "Đã đọc file.", path);
                }
            } catch (Exception e) {
                partial.delete();
                finish(false, false, "Không đọc/ghi được backup. Kiểm tra dung lượng, mạng và quyền truy cập file.", "");
            }
        }, "PetVerse-Backup-transfer");
        worker.setDaemon(true); worker.start();
    }
    private static void copy(InputStream input, OutputStream output) throws IOException {
        byte[] buffer = new byte[32768]; long total = 0; int size;
        while ((size = input.read(buffer)) != -1) {
            total += size;
            if (total > MAX_SIZE) throw new IOException("File too large");
            output.write(buffer, 0, size);
        }
        output.flush();
    }
    private synchronized void finish(boolean ok, boolean cancelled, String message, String path) {
        try {
            JSONObject payload = new JSONObject();
            payload.put("ok", ok); payload.put("cancelled", cancelled);
            payload.put("message", message); payload.put("path", path);
            result = payload.toString();
        } catch (Exception ignored) { result = "{\"ok\":false,\"message\":\"Lỗi đọc file\"}"; }
        pendingPath = ""; busy = false;
    }
}
