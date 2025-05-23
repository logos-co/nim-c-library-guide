/*  Clock Go Bindings
 *  This file defines the Go wrappers for the libclock functions, and the necessary data
 *  functions and data structures in order to interact with the library.
 *
 *  IMPLEMENTATION STEPS:
 *  1. Rename this file to `<your_library_name>.go`
 *  2. Update the package name from `clock` to your library's name
 *  3. Update the C library linking flags:
 *     - Change LDFLAGS paths to point to your C library build directory
 *     - Change -lclock to -l<your_library_name>
 *     - Update the #include path to your library's header file
 *  4. Replace C function calls in the static wrapper functions:
 *     - Replace clock_new, clock_destroy, clock_set_alarm, etc. with your library's functions
 *     - Update function signatures to match your library's API
 *  5. Update the Go struct types:
 *     - Rename Clock struct to your main library object type
 *     - Replace EventCallbacks struct with callbacks relevant to your library
 *     - Remove alarmEvent and create event types for your library's events
 *  6. Update the registry functions:
 *     - Rename clockRegistry, registerClock, unregisterClock to match your object type
 *  7. Modify the event handling:
 *     - Update globalEventCallback to handle your library's events
 *     - Replace the "clock_alarm" case with your library's event types
 *     - Create parsing functions for each of your library's events
 *  8. Replace the example methods:
 *     - Remove SetAlarm and ListAlarms methods
 *     - Add methods that correspond to your library's functionality
 *     - Update method implementations to call your library's C functions
 *  9. Update data structures:
 *     - Remove the Alarm type and create types that match your library's data structures
 *  10. Update error handling and logging messages to reflect your library's context
 *  11. Test the bindings with your specific C library to ensure proper integration
 */

package clock

/*
	#cgo LDFLAGS: -L../third_party/nim-c-library-guide/build/ -lclock
	#cgo LDFLAGS: -L../third_party/nim-c-library-guide -Wl,-rpath,../third_party/nim-c-library-guide/build/

	#include "../third_party/nim-c-library-guide/library/libclock.h"
	#include <stdio.h>
	#include <stdlib.h>

	extern void globalEventCallback(int ret, char* msg, size_t len, void* userData);

	typedef struct {
		int ret;
		char* msg;
		size_t len;
		void* ffiWg;
	} Resp;

	static void* allocResp(void* wg) {
		Resp* r = calloc(1, sizeof(Resp));
		r->ffiWg = wg;
		return r;
	}

	static void freeResp(void* resp) {
		if (resp != NULL) {
			free(resp);
		}
	}

	static char* getMyCharPtr(void* resp) {
		if (resp == NULL) {
			return NULL;
		}
		Resp* m = (Resp*) resp;
		return m->msg;
	}

	static size_t getMyCharLen(void* resp) {
		if (resp == NULL) {
			return 0;
		}
		Resp* m = (Resp*) resp;
		return m->len;
	}

	static int getRet(void* resp) {
		if (resp == NULL) {
			return 0;
		}
		Resp* m = (Resp*) resp;
		return m->ret;
	}

	// resp must be set != NULL in case interest on retrieving data from the callback
	void GoCallback(int ret, char* msg, size_t len, void* resp);

	static void* cGoNewClock(void* resp) {
		// We pass NULL because we are not interested in retrieving data from this callback
		void* ret = clock_new((ClockCallBack) GoCallback, resp);
		return ret;
	}

	static void cGoSetEventCallback(void* clockCtx) {
		// The 'globalEventCallback' Go function is shared amongst all possible Clock instances.

		// Given that the 'globalEventCallback' is shared, we pass again the
		// clockCtx instance but in this case is needed to pick up the correct method
		// that will handle the event.

		// In other words, for every call libclock makes to globalEventCallback,
		// the 'userData' parameter will bring the context of the clock that registered
		// that globalEventCallback.

		// This technique is needed because cgo only allows to export Go functions and not methods.

		clock_set_event_callback(clockCtx, (ClockCallBack) globalEventCallback, clockCtx);
	}

	static void cGoClockDestroy(void* clockCtx, void* resp) {
		clock_destroy(clockCtx, (ClockCallBack) GoCallback, resp);
	}

	static void cGoClockSetAlarm(void* clockCtx, int timeMillis, const char* alarmMsg, void* resp) {
		clock_set_alarm(clockCtx, timeMillis, alarmMsg, (ClockCallBack) GoCallback, resp);
	}

	static void cGoListAlarms(void* clockCtx, void* resp) {
		clock_list_alarms(clockCtx, (ClockCallBack) GoCallback, resp);
	}

*/
import "C"
import (
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"unsafe"
)

//export GoCallback
func GoCallback(ret C.int, msg *C.char, len C.size_t, resp unsafe.Pointer) {
	if resp != nil {
		m := (*C.Resp)(resp)
		m.ret = ret
		m.msg = msg
		m.len = len
		wg := (*sync.WaitGroup)(m.ffiWg)
		wg.Done()
	}
}

// TODO: remove `OnAlarm` callback and add any event callback you want to support
type EventCallbacks struct {
	OnAlarm func(event alarmEvent)
}

// Clock represents an instance of a nim-c-library-guide Clock
// TODO: create a type that represents your library's main object
// you can add fields as needed, but keep the `ctx` and `callbacks` fields
type Clock struct {
	clockCtx  unsafe.Pointer
	callbacks EventCallbacks
}

func NewClock() (*Clock, error) {
	Debug("Creating new Clock")
	clock := &Clock{}

	wg := sync.WaitGroup{}

	var resp = C.allocResp(unsafe.Pointer(&wg))

	defer C.freeResp(resp)

	if C.getRet(resp) != C.RET_OK {
		errMsg := C.GoStringN(C.getMyCharPtr(resp), C.int(C.getMyCharLen(resp)))
		Error("error NewClock: %v", errMsg)
		return nil, errors.New(errMsg)
	}

	wg.Add(1)
	clock.clockCtx = C.cGoNewClock(resp)
	wg.Wait()

	C.cGoSetEventCallback(clock.clockCtx)
	registerClock(clock)

	Debug("Successfully created Clock")
	return clock, nil
}

// The event callback sends back the clock ctx to know to which
// clock is the event being emited for. Since we only have a global
// callback in the go side, We register all the clock's that we create
// so we can later obtain which instance of `Clock` it should
// be invoked depending on the ctx received

// TODO: rename and adapt types to your library's needs
var clockRegistry map[unsafe.Pointer]*Clock

func init() {
	clockRegistry = make(map[unsafe.Pointer]*Clock)
}

// TODO: rename and adapt types to your library's needs
func registerClock(clock *Clock) {
	_, ok := clockRegistry[clock.clockCtx]
	if !ok {
		clockRegistry[clock.clockCtx] = clock
	}
}

// TODO: rename and adapt types to your library's needs
func unregisterClock(clock *Clock) {
	delete(clockRegistry, clock.clockCtx)
}

//export globalEventCallback
func globalEventCallback(callerRet C.int, msg *C.char, len C.size_t, userData unsafe.Pointer) {
	if callerRet == C.RET_OK {
		eventStr := C.GoStringN(msg, C.int(len))
		clock, ok := clockRegistry[userData] // userData contains clock's ctx
		if ok {
			clock.OnEvent(eventStr)
		}
	} else {
		if len != 0 {
			errMsg := C.GoStringN(msg, C.int(len))
			Error("globalEventCallback retCode not ok, retCode: %v: %v", callerRet, errMsg)
		} else {
			Error("globalEventCallback retCode not ok, retCode: %v", callerRet)
		}
	}
}

type jsonEvent struct {
	EventType string `json:"eventType"`
}

// TODO: remove this type and create equivalent types for every event of
// your library
type alarmEvent struct {
	Time int64  `json:"time"`
	Msg  string `json:"msg"`
}

func (c *Clock) RegisterCallbacks(callbacks EventCallbacks) {
	c.callbacks = callbacks
}

func (c *Clock) OnEvent(eventStr string) {

	jsonEvent := jsonEvent{}
	err := json.Unmarshal([]byte(eventStr), &jsonEvent)
	if err != nil {
		Error("could not unmarshal event string: %v", err)

		return
	}

	// TODO: remove the handling of the "cloch_alarm" event and
	// add "case" statements for each event that your library triggers
	switch jsonEvent.EventType {
	case "clock_alarm":
		c.parseAlarmEvent(eventStr)

	}

}

// TODO: adapt to any event your library may trigger
// if there's many different events, make one instance of this
// function for each event and add any additional logic if needed
func (c *Clock) parseAlarmEvent(eventStr string) {

	alarmEvent := alarmEvent{}
	err := json.Unmarshal([]byte(eventStr), &alarmEvent)
	if err != nil {
		Error("could not parse alarm event %v", err)
	}

	if c.callbacks.OnAlarm != nil {
		c.callbacks.OnAlarm(alarmEvent)
	}
}

// TODO: replace `cGoClockDestroy` with your library's equivalent
// and make any adjustments if needed
func (c *Clock) Destroy() error {
	if c == nil {
		err := errors.New("clock is nil")
		Error("Failed to destroy %v", err)
		return err
	}

	Debug("Destroying clock")

	wg := sync.WaitGroup{}
	var resp = C.allocResp(unsafe.Pointer(&wg))
	defer C.freeResp(resp)

	wg.Add(1)
	C.cGoClockDestroy(c.clockCtx, resp)
	wg.Wait()

	if C.getRet(resp) == C.RET_OK {
		unregisterClock(c)
		Debug("Successfully destroyed clock")
		return nil
	}

	errMsg := "error Destroy: " + C.GoStringN(C.getMyCharPtr(resp), C.int(C.getMyCharLen(resp)))
	Error("Failed to destroy clock: %v", errMsg)

	return errors.New(errMsg)
}

// TODO: remove (as this is only an example function)
func (c *Clock) SetAlarm(timeMillis int, alarmMsg string) error {
	if c == nil {
		err := errors.New("clock is nil")
		Error("Failed to set alarm %v", err)
		return err
	}

	Debug("Setting alarm in %v millis", timeMillis)

	wg := sync.WaitGroup{}

	var resp = C.allocResp(unsafe.Pointer(&wg))
	var cAlarmMsg = C.CString(string(alarmMsg))
	defer C.freeResp(resp)
	defer C.free(unsafe.Pointer(cAlarmMsg))

	wg.Add(1)
	C.cGoClockSetAlarm(c.clockCtx, C.int(timeMillis), cAlarmMsg, resp)
	wg.Wait()
	if C.getRet(resp) == C.RET_OK {
		Debug("Successfully set alarm in %v millis", timeMillis)
		return nil
	}
	errMsg := "error SetAlarm: " +
		C.GoStringN(C.getMyCharPtr(resp), C.int(C.getMyCharLen(resp)))
	return fmt.Errorf("SetAlarm: %s", errMsg)
}

// TODO: remove (as this is only an example function)
func (c *Clock) ListAlarms() ([]Alarm, error) {

	if c == nil {
		err := errors.New("clock is nil")
		Error("Failed to list alarms: %v", err)
		return nil, err
	}

	Debug("Fetching scheduled alarms")

	wg := sync.WaitGroup{}
	var resp = C.allocResp(unsafe.Pointer(&wg))
	defer C.freeResp(resp)

	wg.Add(1)
	C.cGoListAlarms(c.clockCtx, resp)
	wg.Wait()

	if C.getRet(resp) == C.RET_OK {
		alarmsStr := C.GoStringN(C.getMyCharPtr(resp), C.int(C.getMyCharLen(resp)))

		// First unmarshal into slice of strings
		var alarmStrings []string
		if err := json.Unmarshal([]byte(alarmsStr), &alarmStrings); err != nil {
			Error("Failed to unmarshal alarm strings JSON: %v", err)
			return nil, fmt.Errorf("failed to unmarshal alarm strings: %w", err)
		}

		// Then unmarshal each string into an Alarm
		var alarms []Alarm
		for _, alarmStr := range alarmStrings {
			var alarm Alarm
			if err := json.Unmarshal([]byte(alarmStr), &alarm); err != nil {
				Error("Failed to unmarshal individual alarm JSON: %v", err)
				return nil, fmt.Errorf("failed to unmarshal alarm: %w", err)
			}
			alarms = append(alarms, alarm)
		}

		Debug("Successfully fetched alarms")
		return alarms, nil
	}

	errMsg := "error ListAlarms: " + C.GoStringN(C.getMyCharPtr(resp), C.int(C.getMyCharLen(resp)))
	Error("Failed to list alarms: %v", errMsg)

	return nil, errors.New(errMsg)
}
