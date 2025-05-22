# libclock.nim - C-exported interface for the Clock shared library
#
# This file implements the public C API for libclock.
# It acts as the bridge between C programs and the internal Nim implementation.
#
# IMPLEMENTATION STEPS:
# 1. Rename this file to `lib<your_library_name>.nim`
# 2. Replace all instances of "clock" with your library name
# 3. Adapt types, callbacks, and event handling to match your library's needs
# 4. Replace imports and request types with ones relevant to your library
# 5. Ensure `lib<YourLibraryName>NimMain()` matches the `--nimMainPrefix` used during compilation
#
# This file defines:
# - Initialization logic for the Nim runtime (once per process)
# - Thread-safe exported procs callable from C
# - Callback registration and invocation for asynchronous communication
#
# See additional TODO comments throughout the file for specific guidance.

{.pragma: exported, exportc, cdecl, raises: [].}
{.pragma: callback, cdecl, raises: [], gcsafe.}
{.passc: "-fPIC".}

when defined(linux):
  {.passl: "-Wl,-soname,libclock.so".}

import std/[locks, typetraits, tables, atomics], chronos, chronicles
import
  ./clock_thread/clock_thread,
  ./alloc,
  ./ffi_types,
  ./clock_thread/inter_thread_communication/clock_thread_request,
  ./clock_thread/inter_thread_communication/requests/
    [clock_lifecycle_request, clock_alarm_request],
  ../src/[clock],
  ./events/[json_alarm_event]

################################################################################
### Not-exported components
################################################################################

# This template checks common parameters passed to exported functions
template checkLibclockParams*(
    ctx: ptr ClockContext, callback: ClockCallBack, userData: pointer
) =
  ctx[].userData = userData

  if isNil(callback):
    return RET_MISSING_CALLBACK

# This template invokes the event callback for internal events
template callEventCallback(ctx: ptr ClockContext, eventName: string, body: untyped) =
  if isNil(ctx[].eventCallback):
    error eventName & " - eventCallback is nil"
    return

  if isNil(ctx[].eventUserData):
    error eventName & " - eventUserData is nil"
    return

  foreignThreadGc:
    try:
      let event = body
      cast[ClockCallBack](ctx[].eventCallback)(
        RET_OK, unsafeAddr event[0], cast[csize_t](len(event)), ctx[].eventUserData
      )
    except Exception, CatchableError:
      let msg =
        "Exception " & eventName & " when calling 'eventCallBack': " &
        getCurrentExceptionMsg()
      cast[ClockCallBack](ctx[].eventCallback)(
        RET_ERR, unsafeAddr msg[0], cast[csize_t](len(msg)), ctx[].eventUserData
      )

# Sends a request to the worker thread and returns success/failure
proc handleRequest(
    ctx: ptr ClockContext,
    requestType: RequestType,
    content: pointer,
    callback: ClockCallBack,
    userData: pointer,
): cint =
  clock_thread.sendRequestToClockThread(ctx, requestType, content, callback, userData).isOkOr:
    let msg = "libclock error: " & $error
    callback(RET_ERR, unsafeAddr msg[0], cast[csize_t](len(msg)), userData)
    return RET_ERR

  return RET_OK

# Constructs the callback handler used internally by clock for alarms
# TODO: remove and implement your own event callbacks if needed
proc onAlarm(ctx: ptr ClockContext): ClockAlarmCallback =
  return proc(time: Moment, msg: string) {.gcsafe.} =
    callEventCallback(ctx, "onAlarm"):
      $JsonAlarmEvent.new(time.epochSeconds(), msg)

### End of not-exported components
################################################################################

################################################################################
### Library setup

# Required for Nim runtime initialization when using --nimMainPrefix
# TODO: rename to lib<YourLibraryName>NimMain
proc libclockNimMain() {.importc.}

# Atomic flag to prevent multiple initializations
var initialized: Atomic[bool]

if defined(android):
  # Redirect chronicles to Android System logs
  when compiles(defaultChroniclesStream.outputs[0].writer):
    defaultChroniclesStream.outputs[0].writer = proc(
        logLevel: LogLevel, msg: LogOutputStr
    ) {.raises: [].} =
      echo logLevel, msg

# Initializes the Nim runtime and foreign-thread GC
proc initializeLibrary() {.exported.} =
  if not initialized.exchange(true):
    ## Every Nim library must call `<prefix>NimMain()` once
    libclockNimMain()
  when declared(setupForeignThreadGc):
    setupForeignThreadGc()
  when declared(nimGC_setStackBottom):
    var locals {.volatile, noinit.}: pointer
    locals = addr(locals)
    nimGC_setStackBottom(locals)

### End of library setup
################################################################################

################################################################################
### Exported procs

# Creates a new instance of the library's context
proc clock_new(
    callback: ClockCallback, userData: pointer
): pointer {.dynlib, exportc, cdecl.} =
  initializeLibrary()

  ## Creates a new instance of the Clock.
  if isNil(callback):
    echo "error: missing callback in clock_new"
    return nil

  ## Create the Clock thread that will keep waiting for req from the Client thread.
  var ctx = clock_thread.createClockThread().valueOr:
    let msg = "Error in createClockThread: " & $error
    callback(RET_ERR, unsafeAddr msg[0], cast[csize_t](len(msg)), userData)
    return nil

  ctx.userData = userData

  let appCallbacks = AppCallbacks(alarmHandler: onAlarm(ctx))

  let retCode = handleRequest(
    ctx,
    RequestType.LIFECYCLE,
    ClockLifecycleRequest.createShared(ClockLifecycleMsgType.CREATE_CLOCK, appCallbacks),
    callback,
    userData,
  )

  if retCode == RET_ERR:
    return nil

  return ctx

# Destroys the Clock thread
proc clock_destroy(
    ctx: ptr ClockContext, callback: ClockCallBack, userData: pointer
): cint {.dynlib, exportc.} =
  initializeLibrary()
  checkLibclockParams(ctx, callback, userData)

  clock_thread.destroyClockThread(ctx).isOkOr:
    let msg = "libclock error: " & $error
    callback(RET_ERR, unsafeAddr msg[0], cast[csize_t](len(msg)), userData)
    return RET_ERR

  ## always need to invoke the callback although we don't retrieve value to the caller
  callback(RET_OK, nil, 0, userData)

  return RET_OK

# Sets the callback for receiving asynchronous events
proc clock_set_event_callback(
    ctx: ptr ClockContext, callback: ClockCallBack, userData: pointer
) {.dynlib, exportc.} =
  initializeLibrary()
  ctx[].eventCallback = cast[pointer](callback)
  ctx[].eventUserData = userData

# Schedules a new alarm
proc clock_set_alarm(
    ctx: ptr ClockContext,
    timeMillis: cint,
    alarmMsg: cstring,
    callback: ClockCallBack,
    userData: pointer,
): cint {.dynlib, exportc.} =
  initializeLibrary()
  checkLibclockParams(ctx, callback, userData)

  handleRequest(
    ctx,
    RequestType.ALARM,
    ClockAlarmRequest.createShared(ClockAlarmMsgType.SET_ALARM, timeMillis, alarmMsg),
    callback,
    userData,
  )

# Requests a list of currently scheduled alarms
proc clock_list_alarms(
    ctx: ptr ClockContext, callback: ClockCallBack, userData: pointer
): cint {.dynlib, exportc.} =
  initializeLibrary()
  checkLibclockParams(ctx, callback, userData)

  handleRequest(
    ctx,
    RequestType.ALARM,
    ClockAlarmRequest.createShared(ClockAlarmMsgType.LIST_ALARMS),
    callback,
    userData,
  )

### End of exported procs
################################################################################
