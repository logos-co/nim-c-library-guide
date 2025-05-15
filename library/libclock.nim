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
### Wrapper around the reliability manager
################################################################################

################################################################################
### Not-exported components

template checkLibclockParams*(
    ctx: ptr ClockContext, callback: ClockCallBack, userData: pointer
) =
  ctx[].userData = userData

  if isNil(callback):
    return RET_MISSING_CALLBACK

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

proc onAlarm(ctx: ptr ClockContext): ClockAlarmCallback =
  return proc(time: Moment, msg: string) {.gcsafe.} =
    callEventCallback(ctx, "onAlarm"):
      $JsonAlarmEvent.new(time, msg)

### End of not-exported components
################################################################################

################################################################################
### Library setup

# Every Nim library must have this function called - the name is derived from
# the `--nimMainPrefix` command line option
proc libclockNimMain() {.importc.}

# To control when the library has been initialized
var initialized: Atomic[bool]

if defined(android):
  # Redirect chronicles to Android System logs
  when compiles(defaultChroniclesStream.outputs[0].writer):
    defaultChroniclesStream.outputs[0].writer = proc(
        logLevel: LogLevel, msg: LogOutputStr
    ) {.raises: [].} =
      echo logLevel, msg

proc initializeLibrary() {.exported.} =
  if not initialized.exchange(true):
    ## Every Nim library needs to call `<yourprefix>NimMain` once exactly, to initialize the Nim runtime.
    ## Being `<yourprefix>` the value given in the optional compilation flag --nimMainPrefix:yourprefix
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

proc clock_new(
    callback: ClockCallback, userData: pointer
): pointer {.dynlib, exportc, cdecl.} =
  initializeLibrary()

  ## Creates a new instance of the Clock.
  if isNil(callback):
    echo "error: missing callback in clock_new"
    return nil

  ## Create the Clock thread that will keep waiting for req from the main thread.
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

proc clock_set_event_callback(
    ctx: ptr ClockContext, callback: ClockCallBack, userData: pointer
) {.dynlib, exportc.} =
  initializeLibrary()
  ctx[].eventCallback = cast[pointer](callback)
  ctx[].eventUserData = userData

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
    ClockAlarmRequest.createShared(ClockAlarmMsgType.LIST_ALARMS, timeMillis, alarmMsg),
    callback,
    userData,
  )

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
