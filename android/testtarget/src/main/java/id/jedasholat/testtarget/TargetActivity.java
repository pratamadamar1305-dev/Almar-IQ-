package id.jedasholat.testtarget;

import android.app.Activity;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.TextView;

/** A deliberately ordinary, launchable app used only by emulator enforcement tests. */
public final class TargetActivity extends Activity {
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        TextView text = new TextView(this);
        text.setText("JEDA_TEST_TARGET_FOREGROUND");
        text.setTextSize(22);
        text.setGravity(Gravity.CENTER);
        setContentView(text);
    }
}
