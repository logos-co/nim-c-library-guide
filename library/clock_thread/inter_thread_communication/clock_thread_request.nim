## This file contains the base message request type that will be handled.
## The requests are created by the main thread and processed by
## the Clock Thread.

import std/json, results
import chronos, chronos/threadsync
import
  ../../ffi_types,
  ./requests/[clock_lifecycle_request, clock_alarm_request],
  ../../../src/clock

type RequestType* {.pure.} = enum
  LIFECYCLE
  ALARM

type ClockThreadRequest* = object
  reqType: RequestType
  reqContent: pointer
  callback: ClockCallBack
  userData: pointer

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

proc `$`*(self: ClockThreadRequest): string =
  return $self.reqType
