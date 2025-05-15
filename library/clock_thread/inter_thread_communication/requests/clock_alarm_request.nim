import std/[options, json, strutils, net]
import chronos, chronicles, results, confutils, confutils/std/net

import ../../../alloc
import ../../../../src/clock

type ClockAlarmMsgType* = enum
  CREATE_ALARM
  LIST_ALARMS

type ClockAlarmRequest* = object
  operation: ClockAlarmMsgType
  timeMillis: cint
  alarmMsg: cstring

proc createShared*(
    T: type ClockAlarmRequest,
    op: ClockAlarmMsgType,
    timeMillis: cint,
    alarmMsg: cstring,
): ptr type T =
  var ret = createShared(T)
  ret[].operation = op
  ret[].timeMillis = timeMillis
  ret[].alarmMsg = alarmMsg.alloc()

  return ret

proc destroyShared(self: ptr ClockAlarmRequest) =
  deallocShared(self[].alarmMsg)
  deallocShared(self)

proc process*(
    self: ptr ClockAlarmRequest, clock: ptr Clock
): Future[Result[string, string]] {.async.} =
  defer:
    destroyShared(self)

  case self.operation
  of CREATE_ALARM:
    clock[].setAlarm(int(self.timeMillis), $self.alarmMsg)
  of LIST_ALARMS:
    return ok($clock[].getAlarms())

  return ok("")
