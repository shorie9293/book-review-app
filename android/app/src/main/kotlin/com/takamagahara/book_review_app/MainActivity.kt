package com.takamagahara.book_review_app

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /// 現世をまたぐ共有フォルダ（SAF）の橋渡し。onActivityResult で結果を受ける。
    private var sharedStorageBridge: SharedStorageBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 通知権限の拒否バナーから OS のアプリ設定画面を開くためのチャネル。
        // Android のアプリ詳細設定は URL スキームで開けないためネイティブ実装を持つ。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.takamagahara.book_review_app/app_settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openAppSettings") {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.fromParts("package", packageName, null)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // 共有ストレージ（SAF）チャネル。フォルダ選択は ACTION_OPEN_DOCUMENT_TREE で
        // 行うため、結果は onActivityResult 経由で返す。
        val storage = SharedStorageBridge(this)
        sharedStorageBridge = storage
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SharedStorageBridge.CHANNEL)
            .setMethodCallHandler(storage)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        sharedStorageBridge?.onActivityResult(requestCode, resultCode, data)
    }
}
