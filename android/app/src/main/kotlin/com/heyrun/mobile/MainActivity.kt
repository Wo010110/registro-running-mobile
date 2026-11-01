package com.heyrun.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificacionGrabacion.manejar(
            this,
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                NotificacionGrabacion.CANAL_PLATAFORMA,
            ),
        )
    }
}
