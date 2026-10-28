pragma Singleton
import QtQml

// Theme-neutral semantic events. The shell owns the sole playback subscriber.
QtObject {
    signal requested(string event)
}
