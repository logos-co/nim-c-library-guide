# Thread Request Dispatcher
#
# This file defines the `ClockThreadRequest` type, which acts as a wrapper for all
# request messages handled by the Clock thread. It supports multiple request types,
# delegating the logic to their respective processors.
#
# IMPLEMENTATION STEPS:
# 1. Rename this file to `<your_library_name>_thread_request.nim` 
# 2. Add any new request types to the `RequestType` enum
# 3. Include your request modules in the imports and remove clock related imports
# 4. Update the `process()` dispatch logic to handle your request types
#
# See additional TODO comments throughout the file for specific guidance.

import std/json, results
import chronos, chronos/threadsync

# TODO: Import additional request modules for your features here
# TODO: Remove imports with the word "clock"
import
  ../../ffi_types,
  ./requests/[clock_lifecycle_request, clock_alarm_request],
  ../../../src/clock

# TODO: Add new request categories as needed
type RequestType* {.pure.} = enum
  LIFECYCLE
  ALARM

# Central request object passed to the Clock thread
# reqContent is a pointer to the actual request object (e.g. ClockAlarmRequest)
type ClockThreadRequest* = object
  reqType: RequestType
  reqContent: pointer
  callback: ClockCallBack
  userData: pointer

# Shared memory allocation for ClockThreadRequest
proc createShared*(
    T: type ClockThreadRequest,
    reqType: RequestType,
    reqContent: pointer,
    callback: ClockCallBack,
    userData: pointer,
): ptr type T =
  var ret = createShared(T)
  ret[].reqType = reqType
  ret[].reqContent = reqContent
  ret[].callback = callback
  ret[].userData = userData
  return ret

# Handles responses of type Result[string, string] or Result[void, string]
# Converts the result into a C callback invocation with either RET_OK or RET_ERR
proc handleRes[T: string | void](
    res: Result[T, string], request: ptr ClockThreadRequest
) =
  ## Handles the Result responses, which can either be Result[string, string] or
  ## Result[void, string].

  defer:
    deallocShared(request)

  if res.isErr():
    foreignThreadGc:
      let msg = "libclock error: handleRes fireSyncRes error: " & $res.error
      request[].callback(
        RET_ERR, unsafeAddr msg[0], cast[csize_t](len(msg)), request[].userData
      )
    return

  foreignThreadGc:
    var msg: cstring = ""
    when T is string:
      msg = res.get().cstring()
    request[].callback(
      RET_OK, unsafeAddr msg[0], cast[csize_t](len(msg)), request[].userData
    )
  return

# Dispatcher for processing the request based on its type
# Casts reqContent to the correct request struct and runs its `.process()` logic
proc process*(
    T: type ClockThreadRequest, request: ptr ClockThreadRequest, clock: ptr Clock
) {.async.} =
  let retFut =
    case request[].reqType
    of RequestType.LIFECYCLE:
      cast[ptr ClockLifecycleRequest](request[].reqContent).process(clock)
    of RequestType.ALARM:
      cast[ptr ClockAlarmRequest](request[].reqContent).process(clock)

  handleRes(await retFut, request)

# String representation of the request type
proc `$`*(self: ClockThreadRequest): string =
  return $self.reqType
