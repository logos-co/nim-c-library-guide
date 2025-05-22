# Thread Request Example Implementation
#
# This file defines the `ClockAlarmRequest` type and its lifecycle, including memory
# management and request processing. This structure is used for communicating between
# the Client and Clock threads
#
# IMPLEMENTATION STEPS:
# 1. Rename this file to `<your_library_name>_<your_request_name>_request.nim`
# 2  Update imports to include your library's logic
# 3. Rename ClockAlarmRequest to `<YourRequestName>Request` and replace all usages of it
# 4. Add or remove fields in <YourRequestName>Request` to match your request's structure
# 5. Rename ClockAlarmMsgType to `<YourRequestName>MsgType` and replace all usages of it
# 6. Update the enum values in `<YourRequestName>MsgType` to reflect your supported operations
# 7. Modify the `createShared()` procedure to initialize your specific fields.
#    Nim GC'd types must be allocated in the shared memory
# 8. Modify `destroyShared()` if you allocate/deallocate any new fields
#    Nim GC'd types should be deallocated from the shared memory
# 9. Update the `process()` procedure to define your custom behavior
#
# See additional TODO comments throughout the file for specific guidance.

import std/[options, json, strutils, net, sequtils]
import chronos, chronicles, results, confutils, confutils/std/net

import ../../../alloc
# TODO: Replace import with ones related to your library's logic
import ../../../../src/clock

# TODO: Rename and update enum values for your request type
type ClockAlarmMsgType* = enum
  SET_ALARM
  LIST_ALARMS

# TODO: Rename the type and update fields to match your custom request
type ClockAlarmRequest* = object
  operation: ClockAlarmMsgType
  timeMillis: cint
  alarmMsg: cstring

# TODO: Modify for your request's specific field initialization
# TODO: Allocate parameters of GC'd types to the shared memory
proc createShared*(
    T: type ClockAlarmRequest,
    op: ClockAlarmMsgType,
    timeMillis: cint = 0,
    alarmMsg: cstring = "",
): ptr type T =
  var ret = createShared(T)
  ret[].operation = op
  ret[].timeMillis = timeMillis
  ret[].alarmMsg = alarmMsg.alloc()

  return ret

# TODO: Free any newly added fields here if you change the object structure
# TODO: Deallocate parameters of GC'd types from the shared memory
proc destroyShared(self: ptr ClockAlarmRequest) =
  deallocShared(self[].alarmMsg)
  deallocShared(self)

# TODO: Implement the request logic for your new operation types
proc process*(
    self: ptr ClockAlarmRequest, clock: ptr Clock
): Future[Result[string, string]] {.async.} =
  defer:
    destroyShared(self)

  case self.operation
  of SET_ALARM:
    clock[].setAlarm(int(self.timeMillis), $self.alarmMsg)
  of LIST_ALARMS:
    let alarmStrings = clock[].getAlarms().mapIt($it)
    return ok($(%*alarmStrings))

  return ok("")
