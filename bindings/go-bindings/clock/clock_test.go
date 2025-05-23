// Test file for example Clock library's Go bindings
// Rename this file and replace the tests for your library's tests

package clock

import (
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

// Test basic creation, cleanup, and reset
func TestLifecycle(t *testing.T) {
	clock, err := NewClock()
	require.NoError(t, err)
	require.NotNil(t, clock, "Expected Clock to be not nil")

	err = clock.Destroy()
	require.NoError(t, err)
}

func TestAlarmEvent(t *testing.T) {
	clock, err := NewClock()
	require.NoError(t, err)
	require.NotNil(t, clock, "Expected Clock to be not nil")

	defer clock.Destroy()

	// Use a channel for signaling
	alarmChan := make(chan alarmEvent, 1)

	callbacks := EventCallbacks{
		OnAlarm: func(event alarmEvent) {
			// Non-blocking send to channel
			select {
			case alarmChan <- event:
			default:
				// Avoid blocking if channel is full or test already timed out
			}
		},
	}

	// Register alarm callback
	clock.RegisterCallbacks(callbacks)

	alarmMsg := "this is my alarm"
	err = clock.SetAlarm(1000, alarmMsg)
	require.NoError(t, err)

	// Verification - Wait on channel with timeout
	select {
	case receivedAlarm := <-alarmChan:
		epochSeconds := time.Now().Unix()

		// Mark as called implicitly since we received on channel
		if receivedAlarm.Msg != alarmMsg {
			t.Errorf("OnAlarm called with wrong alarm message: got %q, want %q", receivedAlarm.Msg, alarmMsg)
		}

		if epochSeconds-receivedAlarm.Time > 1 {
			t.Errorf("Alarm was set at %d but current time is %d", receivedAlarm.Time, epochSeconds)
		}

	case <-time.After(2 * time.Second):
		// If timeout occurs, the channel receive failed.
		t.Errorf("Timed out waiting for OnAlarm callback on alarmChan")
	}

}

func TestListAlarms(t *testing.T) {
	clock, err := NewClock()
	require.NoError(t, err)
	require.NotNil(t, clock, "Expected Clock to be not nil")

	defer clock.Destroy()

	// fist try to getch alarms when empty
	alarms, err := clock.ListAlarms()
	require.NoError(t, err)

	require.Equal(t, len(alarms), 0, "Expected to be no scheduled alarms")

	alarmMsg := "this is my alarm"
	err = clock.SetAlarm(1000, alarmMsg)
	require.NoError(t, err)

	err = clock.SetAlarm(5000, alarmMsg)
	require.NoError(t, err)

	alarms, err = clock.ListAlarms()
	require.NoError(t, err)
	require.Equal(t, len(alarms), 2, "Expected to be two alarms scheduled")

	time.Sleep(2 * time.Second)

	alarms, err = clock.ListAlarms()
	require.NoError(t, err)
	require.Equal(t, len(alarms), 1, "Expected to be one alarm scheduled")

}
