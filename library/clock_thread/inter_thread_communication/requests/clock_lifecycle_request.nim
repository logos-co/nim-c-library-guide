import std/[options, json, strutils, net]
import chronos, chronicles, results, confutils, confutils/std/net

import ../../../alloc
import ../../../../src/clock

type ClockLifecycleMsgType* = enum
  CREATE_CLOCK

type ClockLifecycleRequest* = object
  operation: ClockLifecycleMsgType
  appCallbacks: AppCallbacks

proc createShared*(
    T: type ClockLifecycleRequest,
    op: ClockLifecycleMsgType,
    appCallbacks: AppCallbacks = nil,
): ptr type T =
  var ret = createShared(T)
  ret[].operation = op
  ret[].appCallbacks = appCallbacks
  return ret

proc destroyShared(self: ptr ClockLifecycleRequest) =
  deallocShared(self)

proc process*(
    self: ptr ClockLifecycleRequest, clock: ptr Clock
): Future[Result[string, string]] {.async.} =
  defer:
    destroyShared(self)

  case self.operation
  of CREATE_CLOCK:
    clock[] = Clock.new(self.appCallbacks)

  return ok("")
