/**
* libclock.h - C Interface for Example Library
*
* This header provides the public API for libclock
*
* IMPLEMENTATION STEPS:
* 1. Rename this file to `lib<your_library_name>.h`
* 2. Replace "clock" in all function names with your library name
* 3. Rename the ClockCallBack type to <YourLibraryName>Callback
* 4. Replace the clock functions with your library's specific functions
* 5. Update the header guards to match your library name
*
* See additional TODO comments throughout the file for specific guidance.
*
* To see the auto-generated header by Nim, run `make libclock` from the
* repository root. The generated file will be created at:
* nimcache/release/libclock/libclock.h
*/

// TODO: change clock for your library's name
#ifndef __libclock__
#define __libclock__

#include <stddef.h>
#include <stdint.h>

// The possible returned values for the functions that return int
#define RET_OK                0
#define RET_ERR               1
#define RET_MISSING_CALLBACK  2

#ifdef __cplusplus
extern "C" {
#endif

// TODO: change ClockCallback to <YourLibraryName>Callback
typedef void (*ClockCallBack) (int callerRet, const char* msg, size_t len, void* userData);

// TODO: replace the clock functions for your library's functions
// TODO: replace the ClockCallBack parameter for <YourLibraryName>Callback
void* clock_new(ClockCallBack callback,
             void* userData);

int clock_destroy(void* ctx,
                 ClockCallBack callback,
                 void* userData);

void clock_set_event_callback(void* ctx,
                             ClockCallBack callback,
                             void* userData);

int clock_set_alarm(void* ctx,
                    int timeMillis,
                    const char* alarmMsg,
                    ClockCallBack callback,
                    void* userData);

int clock_list_alarms(void* ctx,
                    ClockCallBack callback,
                    void* userData);

#ifdef __cplusplus
}
#endif

// TODO: change clock for your library's name
#endif /* __libclock__ */