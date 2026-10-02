package com.petverse.bluetooth;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.provider.Settings;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.TimeUnit;

/** Paired-device RFCOMM. All blocking I/O runs off the Godot/UI threads. */
public final class PetVerseBluetooth extends GodotPlugin {
    private static final UUID SERVICE = UUID.fromString("dd72dfea-7f44-4aa6-867e-1597279181ca");
    private static final int MAX_PACKET = 16384;
    private final ArrayBlockingQueue<String> incoming = new ArrayBlockingQueue<>(128);
    private volatile ArrayBlockingQueue<byte[]> outgoing = new ArrayBlockingQueue<>(128);
    private volatile String state = "idle";
    private volatile String error = "";
    private volatile int generation = 0;
    private BluetoothServerSocket server;
    private BluetoothSocket socket;

    public PetVerseBluetooth(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "PetVerseBluetooth"; }

    private BluetoothAdapter adapter() {
        Activity activity = getActivity();
        if (activity == null) return null;
        BluetoothManager manager = (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
        return manager == null ? null : manager.getAdapter();
    }
    private boolean permitted() {
        Activity activity = getActivity();
        return activity != null && (Build.VERSION.SDK_INT < 31 ||
            activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED);
    }
    private boolean usable() {
        if (!permitted()) { error = "Hãy nhấn Cho phép Bluetooth trước"; return false; }
        BluetoothAdapter adapter = adapter();
        if (adapter == null) { error = "Điện thoại không hỗ trợ Bluetooth"; return false; }
        if (!adapter.isEnabled()) { error = "Hãy bật Bluetooth trong cài đặt Android"; return false; }
        return true;
    }
    @UsedByGodot public String last_error() { return error; }
    @UsedByGodot public String connection_state() { return state; }
    @UsedByGodot public void request_access() {
        Activity activity = getActivity();
        if (activity == null) return;
        activity.runOnUiThread(() -> {
            if (!permitted() && Build.VERSION.SDK_INT >= 31) {
                activity.requestPermissions(new String[]{Manifest.permission.BLUETOOTH_CONNECT}, 28411);
            } else {
                BluetoothAdapter adapter = adapter();
                if (adapter != null && !adapter.isEnabled())
                    activity.startActivity(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE));
            }
        });
    }
    @UsedByGodot public void open_settings() {
        Activity activity = getActivity();
        if (activity != null) activity.runOnUiThread(() -> activity.startActivity(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS)));
    }
    @UsedByGodot public String paired_devices() {
        JSONArray devices = new JSONArray();
        if (!usable()) return devices.toString();
        try {
            for (BluetoothDevice device : adapter().getBondedDevices()) {
                JSONObject item = new JSONObject();
                item.put("address", device.getAddress());
                item.put("name", device.getName() == null ? device.getAddress() : device.getName());
                devices.put(item);
            }
        } catch (Exception e) { error = "Không đọc được thiết bị Bluetooth đã ghép đôi"; }
        return devices.toString();
    }
    @UsedByGodot public synchronized boolean host_room() {
        close_room();
        if (!usable()) return false;
        final int token = generation;
        state = "waiting";
        worker("PetVerse-BT-accept", () -> {
            try {
                BluetoothServerSocket listener = adapter().listenUsingRfcommWithServiceRecord("PetVerse", SERVICE);
                synchronized (this) {
                    if (token != generation) { listener.close(); return; }
                    server = listener;
                }
                BluetoothSocket accepted = listener.accept();
                listener.close();
                synchronized (this) {
                    if (token != generation) { accepted.close(); return; }
                    server = null;
                    socket = accepted;
                }
                startConnected(accepted, token);
            } catch (Exception e) { fail(token, "Không tạo được phòng Bluetooth hoặc kết nối đã đóng"); }
        });
        return true;
    }
    @UsedByGodot public synchronized boolean join_room(String address) {
        close_room();
        if (!usable()) return false;
        if (!BluetoothAdapter.checkBluetoothAddress(address)) { error = "Địa chỉ Bluetooth không hợp lệ"; return false; }
        final int token = generation;
        state = "connecting";
        worker("PetVerse-BT-connect", () -> {
            try {
                BluetoothSocket candidate = adapter().getRemoteDevice(address).createRfcommSocketToServiceRecord(SERVICE);
                synchronized (this) {
                    if (token != generation) { candidate.close(); return; }
                    socket = candidate; // close_room also cancels a blocking connect().
                }
                candidate.connect();
                startConnected(candidate, token);
            } catch (Exception e) { fail(token, "Không vào được phòng Bluetooth. Kiểm tra máy kia đã tạo phòng."); }
        });
        return true;
    }
    private void startConnected(BluetoothSocket connected, int token) throws IOException {
        DataInputStream reader = new DataInputStream(connected.getInputStream());
        DataOutputStream writer = new DataOutputStream(connected.getOutputStream());
        synchronized (this) {
            if (token != generation) { connected.close(); return; }
            state = "connected";
        }
        final ArrayBlockingQueue<byte[]> connectionQueue = outgoing;
        worker("PetVerse-BT-write", () -> {
            try {
                while (token == generation) {
                    byte[] packet = connectionQueue.poll(500, TimeUnit.MILLISECONDS);
                    // Re-check generation so an old writer cannot send to an old socket.
                    if (token != generation) break;
                    if (packet != null) { writer.writeInt(packet.length); writer.write(packet); writer.flush(); }
                }
            } catch (Exception e) { fail(token, "Mất kết nối Bluetooth"); }
        });
        try {
            while (token == generation) {
                int size = reader.readInt();
                if (size <= 0 || size > MAX_PACKET) throw new IOException("Invalid frame");
                byte[] bytes = new byte[size];
                reader.readFully(bytes);
                synchronized (this) {
                    if (token != generation) break;
                    if (!incoming.offer(new String(bytes, StandardCharsets.UTF_8))) throw new IOException("Receive queue full");
                }
            }
        } catch (Exception e) { fail(token, "Người chơi còn lại đã ngắt Bluetooth"); }
    }
    @UsedByGodot public synchronized boolean send_packet(String text) {
        if (!state.equals("connected")) return false;
        byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
        return bytes.length > 0 && bytes.length <= MAX_PACKET && outgoing.offer(bytes);
    }
    @UsedByGodot public synchronized String take_packets() {
        JSONArray packets = new JSONArray();
        for (int i = 0; i < 64; i++) {
            String packet = incoming.poll();
            if (packet == null) break;
            packets.put(packet);
        }
        return packets.toString();
    }
    private synchronized void fail(int token, String message) {
        if (token != generation) return;
        close_room();
        error = message;
        state = "error";
    }
    @UsedByGodot public synchronized void close_room() {
        generation++;
        try { if (server != null) server.close(); } catch (IOException ignored) {}
        try { if (socket != null) socket.close(); } catch (IOException ignored) {}
        server = null;
        socket = null;
        incoming.clear();
        outgoing = new ArrayBlockingQueue<>(128);
        state = "idle";
        error = "";
    }
    @Override public void onMainDestroy() { close_room(); }
    private static void worker(String name, Runnable work) {
        Thread thread = new Thread(work, name);
        thread.setDaemon(true);
        thread.start();
    }
}
