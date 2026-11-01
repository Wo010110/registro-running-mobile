package com.heyrun.mobile

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Reescribe el texto de la notificación del servicio en primer plano del GPS
 * (geolocator_android 5.2.1: id 75415, canal "geolocator_channel_01"). Es la
 * misma notificación: no se añade otra ni se toca el servicio.
 */
object NotificacionGrabacion {
    const val CANAL_PLATAFORMA = "com.heyrun.mobile/notificacion"
    private const val ID = 75415
    private const val CANAL = "geolocator_channel_01"

    fun manejar(contexto: Context, canal: MethodChannel) {
        canal.setMethodCallHandler { llamada, resultado ->
            if (llamada.method != "actualizar") {
                resultado.notImplemented()
                return@setMethodCallHandler
            }
            val titulo = llamada.argument<String>("titulo") ?: ""
            val texto = llamada.argument<String>("texto") ?: ""
            resultado.success(actualizar(contexto.applicationContext, titulo, texto))
        }
    }

    private fun actualizar(ctx: Context, titulo: String, texto: String): Boolean {
        return try {
            val gestor = NotificationManagerCompat.from(ctx)
            val sistema = ctx.getSystemService(NotificationManager::class.java)
            // Solo si el servicio ya la publicó: así nunca queda una
            // notificación fija suelta después de terminar la actividad.
            val activa = sistema.activeNotifications.any { it.id == ID }
            if (!activa) return false
            val intento = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            val abrir = intento?.let {
                it.setPackage(null)
                it.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                var banderas = PendingIntent.FLAG_UPDATE_CURRENT
                if (Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
                    banderas = banderas or PendingIntent.FLAG_IMMUTABLE
                }
                PendingIntent.getActivity(ctx, 0, it, banderas)
            }
            // Mismo icono que usa geolocator por defecto.
            val icono = ctx.resources.getIdentifier("ic_launcher", "mipmap", ctx.packageName)
            val notificacion = NotificationCompat.Builder(ctx, CANAL)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setSmallIcon(icono)
                .setContentTitle(titulo)
                .setContentText(texto)
                .setContentIntent(abrir)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build()
            gestor.notify(ID, notificacion)
            true
        } catch (e: Exception) {
            false
        }
    }
}
