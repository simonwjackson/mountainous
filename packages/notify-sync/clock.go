package notifysync

import "time"

// Clock controls scheduling, not notification timestamps. Configure it before
// Run starts. Production uses WallClock; tests can advance manual time.
type Clock interface {
	Now() time.Time
	NewTimer(time.Duration) Timer
}
type Timer interface {
	C() <-chan time.Time
	Stop() bool
}
type WallClock struct{}

func (WallClock) Now() time.Time                 { return time.Now() }
func (WallClock) NewTimer(d time.Duration) Timer { return wallTimer{time.NewTimer(d)} }

type wallTimer struct{ *time.Timer }

func (t wallTimer) C() <-chan time.Time { return t.Timer.C }
