package com.kobayashi.cymva;

import android.media.MediaMetadataRetriever;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import java.util.HashMap;

public class MyFlutterActivity extends FlutterActivity {
    private static final String CHANNEL = "video_rotation"; // Flutter 側と一致させる

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("getVideoRotation")) {
                        String videoUrl = call.arguments();
                        try {
                            MediaMetadataRetriever retriever = new MediaMetadataRetriever();
                            if (videoUrl.startsWith("http") || videoUrl.startsWith("https")) {
                                retriever.setDataSource(videoUrl, new HashMap<>());
                            } else {
                                retriever.setDataSource(videoUrl);
                            }
                            String rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION);
                            retriever.release();
                            result.success(Integer.parseInt(rotation));
                        } catch (Exception e) {
                            e.printStackTrace(); // エラーをログに出力
                            result.error("UNAVAILABLE", "Video rotation not available.", null);
                        }
                    } else {
                        result.notImplemented();
                    }
                }
            );
    }
}
