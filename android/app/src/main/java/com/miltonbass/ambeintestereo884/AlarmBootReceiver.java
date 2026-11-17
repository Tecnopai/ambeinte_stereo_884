package com.miltonbass.ambientestereo884;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Android borra las alarmas al reiniciar el teléfono (o al actualizar la app):
 * aquí se vuelve a programar el despertador, si estaba encendido.
 */
public class AlarmBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        RadioAlarm.schedule(context);
    }
}
