package com.designers.giftunwrap;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Build;
import android.view.HapticFeedbackConstants;
import android.view.View;

import java.util.EnumMap;
import java.util.Map;

/** Haptics (through the view, like Telegram) and synthesised sounds (no audio files). */
public final class GUFeedback {
    public enum Sound {ARRIVE, CREAK, CRACKLE, SHATTER, SHIMMER, PATTERN, ROLL, TAP, WHOOSH, LAND, SWELL, TOAST}

    private static final int RATE = 44100;
    private final View view;
    private final AudioManager audio;
    private final Map<Sound, AudioTrack> tracks = new EnumMap<>(Sound.class);
    public boolean soundsEnabled = true;
    public boolean hapticsEnabled = true;

    public GUFeedback(View view) {
        this.view = view;
        this.audio = (AudioManager) view.getContext().getSystemService(Context.AUDIO_SERVICE);
    }

    // --- haptics

    public void tension() {
        haptic(Build.VERSION.SDK_INT >= 27 ? HapticFeedbackConstants.TEXT_HANDLE_MOVE : HapticFeedbackConstants.CLOCK_TICK);
    }

    public void crackle() {
        haptic(HapticFeedbackConstants.KEYBOARD_TAP);
    }

    public void shatter() {
        haptic(HapticFeedbackConstants.LONG_PRESS);
        view.postDelayed(() -> haptic(Build.VERSION.SDK_INT >= 30 ? HapticFeedbackConstants.CONFIRM : HapticFeedbackConstants.VIRTUAL_KEY), 120);
    }

    public void tick() {
        haptic(HapticFeedbackConstants.CLOCK_TICK);
    }

    public void tap() {
        haptic(HapticFeedbackConstants.VIRTUAL_KEY);
    }

    private void haptic(int constant) {
        if (hapticsEnabled) {
            view.performHapticFeedback(constant, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING);
        }
    }

    // --- sounds

    /** Synthesises every sound once (≈50 ms on a phone). Call off the first frame if possible. */
    public void prepare() {
        if (!tracks.isEmpty()) {
            return;
        }
        for (Sound s : Sound.values()) {
            short[] pcm = toPcm(synthesize(s));
            AudioTrack track = new AudioTrack.Builder()
                    .setAudioAttributes(new AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build())
                    .setAudioFormat(new AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(RATE)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build())
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .setBufferSizeInBytes(pcm.length * 2)
                    .build();
            track.write(pcm, 0, pcm.length);
            tracks.put(s, track);
        }
    }

    public void play(Sound s, float gain) {
        if (!soundsEnabled || audio == null || audio.getRingerMode() != AudioManager.RINGER_MODE_NORMAL) {
            return;
        }
        AudioTrack t = tracks.get(s);
        if (t == null) {
            return;
        }
        try {
            if (t.getPlayState() == AudioTrack.PLAYSTATE_PLAYING) {
                t.stop();
            }
            t.reloadStaticData();
            t.setVolume(gain);
            t.play();
        } catch (IllegalStateException ignored) {
        }
    }

    public void play(Sound s) {
        play(s, 1f);
    }

    public void release() {
        for (AudioTrack t : tracks.values()) {
            t.release();
        }
        tracks.clear();
    }

    private static short[] toPcm(float[] x) {
        float peak = 0f;
        for (float v : x) {
            peak = Math.max(peak, Math.abs(v));
        }
        float k = peak > 0.95f ? 0.95f / peak : 1f;
        short[] out = new short[x.length];
        for (int i = 0; i < x.length; i++) {
            out[i] = (short) (x[i] * k * 32767f);
        }
        return out;
    }

    private static float[] synthesize(Sound s) {
        Synth y = new Synth();
        switch (s) {
            case ARRIVE:
                y.sweep(0f, 700f, 180f, 0.35f, 0.06f, 0.35f);
                y.ping(0.06f, 1568f, 0.35f, 0.08f);
                y.ping(0.14f, 2093f, 0.4f, 0.07f);
                break;
            case CREAK:
                y.noise(0f, 0.05f, 2500f, 9000f, 0.001f, 0.01f, 0.25f);
                break;
            case CRACKLE:
                for (int k = 0; k < 10; k++) {
                    float j = y.random() * 0.01f;
                    y.noise(k * 0.025f + j, 0.015f, 3000f, 12000f, 0.0005f, 0.003f, 0.25f + 0.04f * k);
                }
                break;
            case SHATTER:
                y.sweep(0f, 130f, 70f, 1.2f, 0.18f, 0.55f);
                y.noise(0f, 1.0f, 1500f, 14000f, 0.001f, 0.09f, 0.45f);
                for (int k = 0; k < 60; k++) {
                    float r0 = y.random(), r1 = y.random(), r2 = y.random(), r3 = y.random();
                    float t = (float) (-Math.log(Math.max(0.001f, r0)) * 0.12f);
                    y.ping(t, 2200f + r1 * 7300f, 0.03f + r2 * 0.09f, (0.02f + r3 * 0.05f) * (float) Math.exp(-t * 2f));
                }
                break;
            case SHIMMER: {
                float[] notes = {784, 988, 1175, 1568, 1976, 2349, 3136};
                for (int i = 0; i < notes.length; i++) {
                    y.ping(i * 0.055f, notes[i], 0.9f, 0.05f);
                }
                break;
            }
            case PATTERN:
                for (int k = 0; k < 14; k++) {
                    float r0 = y.random(), r1 = y.random();
                    y.ping(k * 0.03f + r0 * 0.02f, 3400f + r1 * 2800f, 0.03f, 0.03f);
                }
                break;
            case ROLL:
                for (int k = 0; k < 18; k++) {
                    y.noise(0.6f * (float) Math.pow(k / 18f, 1.6f), 0.01f, 3000f, 9000f, 0.0005f, 0.002f, 0.12f);
                }
                break;
            case TAP:
                y.noise(0f, 0.05f, 1800f, 7000f, 0.0005f, 0.004f, 0.3f);
                y.ping(0f, 420f, 0.012f, 0.25f);
                break;
            case WHOOSH:
                y.noise(0f, 1.1f, 400f, 7000f, 0.45f, 0.35f, 0.18f);
                for (int k = 0; k < 12; k++) {
                    y.ping(0.1f + k * 0.07f, 2600f + 180f * k, 0.08f, 0.03f);
                }
                break;
            case LAND:
                y.sweep(0f, 300f, 1200f, 0.3f, 0.05f, 0.3f);
                y.ping(0.03f, 2637f, 0.5f, 0.07f);
                y.ping(0.1f, 3951f, 0.45f, 0.05f);
                break;
            case SWELL: {
                y.noise(0f, 0.9f, 2500f, 11000f, 0.45f, 0.4f, 0.06f);
                float[] notes = {1568, 2349, 3136, 3951};
                for (int i = 0; i < notes.length; i++) {
                    y.ping(0.12f + i * 0.06f, notes[i], 0.6f, 0.03f);
                }
                break;
            }
            case TOAST:
                y.ping(0f, 1760f, 0.12f, 0.05f);
                break;
        }
        return y.out();
    }

    /** Pings, pitch sweeps and band-passed noise mixed into one mono buffer. */
    private static final class Synth {
        private float[] buf = new float[0];
        private long seed = 7;

        float random() {
            seed = (seed * 1664525L + 1013904223L) & 0xffffffffL;
            return seed / 4294967296f;
        }

        private void ensure(int n) {
            if (buf.length < n) {
                float[] b = new float[n];
                System.arraycopy(buf, 0, b, 0, buf.length);
                buf = b;
            }
        }

        void ping(float t0, float f, float decay, float gain) {
            int n = (int) ((decay * 6f + 0.02f) * RATE);
            int start = (int) (t0 * RATE);
            ensure(start + n);
            for (int i = 0; i < n; i++) {
                double t = (double) i / RATE;
                double attack = Math.min(1.0, t / 0.002);
                double v = Math.sin(2 * Math.PI * f * t) + 0.35 * Math.sin(2 * Math.PI * f * 2.76 * t + 1.0) * Math.exp(-t / (decay * 0.5));
                buf[start + i] += (float) (v * Math.exp(-t / decay) * attack * gain);
            }
        }

        void sweep(float t0, float f0, float f1, float duration, float decay, float gain) {
            int n = (int) (duration * RATE);
            int start = (int) (t0 * RATE);
            ensure(start + n);
            double phase = 0;
            for (int i = 0; i < n; i++) {
                double t = (double) i / RATE;
                double f = f1 + (f0 - f1) * Math.exp(-t * 20.0);
                phase += 2 * Math.PI * f / RATE;
                double attack = Math.min(1.0, t / 0.002);
                buf[start + i] += (float) (Math.sin(phase) * Math.exp(-t / decay) * attack * gain);
            }
        }

        void noise(float t0, float duration, float low, float high, float attack, float decay, float gain) {
            int n = (int) (duration * RATE);
            int start = (int) (t0 * RATE);
            ensure(start + n);
            double f0 = Math.sqrt(low * high);
            double q = f0 / Math.max(1.0, high - low);
            double w0 = 2 * Math.PI * f0 / RATE;
            double alpha = Math.sin(w0) / (2 * q);
            double a0 = 1 + alpha;
            double b0 = alpha / a0, b2 = -alpha / a0, a1 = -2 * Math.cos(w0) / a0, a2 = (1 - alpha) / a0;
            double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
            for (int i = 0; i < n; i++) {
                double t = (double) i / RATE;
                double x = random() * 2.0 - 1.0;
                double yv = b0 * x + b2 * x2 - a1 * y1 - a2 * y2;
                x2 = x1;
                x1 = x;
                y2 = y1;
                y1 = yv;
                double env = Math.min(1.0, t / Math.max(0.0001, attack)) * Math.exp(-Math.max(0.0, t - attack) / decay);
                buf[start + i] += (float) (yv * env * gain * 2.5);
            }
        }

        float[] out() {
            return buf;
        }
    }
}
