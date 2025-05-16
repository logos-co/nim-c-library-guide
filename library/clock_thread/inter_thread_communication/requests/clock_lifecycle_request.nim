# Thread Request Example Implementation
#
# This file defines the `ClockLifecycleRequest` type and its lifecycle, including memory
# management and request processing. This structure is used for communicating with the
# main thread, which is the one that runs the Clock
#
# IMPLEMENTATION STEPS:
# 1. Rename this file to `<your_library_name>_<your_request_name>_request.nim`
# 2. Update imports to include your library's logic
# 3. Rename ClockLifecycleRequest to `<YourRequestName>Request` and replace all usages of it
# 4. Add or remove fields in `<YourRequestName>Request` to match your request's structure
# 5. Rename ClockLifecycleMsgType to `<YourRequestName>MsgType` and replace all usages of it
# 6. Update the enum values in `<YourRequestName>MsgType` to reflect your supported operations
# 7. Modify the `createShared()` procedure to initialize your specific fields.
#    Nim GC'd types must be allocated in the shared memory
# 8. Modify `destroyShared()` if you allocate/deallocate any new fields
#    Nim GC'd types should be deallocated from the shared memory
# 9. Update the `process()` procedure to define your custom behavior
#
# See additional TODO comments throughout the file for specific guidance.

import std/[options, json, strutils, net]
import chronos, chronicles, results, confutils, confutils/std/net

import ../../../alloc
# TODO: Replace import with ones related to your library's logic
import ../../../../src/clock

# TODO: Rename and update enum values for your request type
type ClockLifecycleMsgType* = enum
  CREATE_CLOCK

# TODO: Rename the type and update fields to match your custom request
type ClockLifecycleRequest* = object
  operation: ClockLifecycleMsgType
  appCallbacks: AppCallbacks

# TODO: Modify for your request's specific field initialization
# TODO: Allocate parameters of GC'd types to the shared memory
proc createShared*(
    T: type ClockLifecycleRequest,
    op: ClockLifecycleMsgType,
    appCallbacks: AppCallbacks = nil,
): ptr type T =
  var ret = createShared(T)
  ret[].operation = op
  ret[].appCallbacks = appCallbacks
  return ret

# TODO: Free any newly added fields here if you change the object structure
# TODO: Deallocate parameters of GC'd types from the shared memory
proc destroyShared(self: ptr ClockLifecycleRequest) =
  deallocShared(self)

# TODO: Implement the request logic for your new operation types
proc process*(
    self: ptr ClockLifecycleRequest, clock: ptr Clock
): Future[Result[string, string]] {.async.} =
  defer:
    destroyShared(self)

  case self.operation
  of CREATE_CLOCK:
    clock[] = Clock.new(self.appCallbacks)

  return ok("")
