import chronos, std/json, chronicles

type
  ClockAlarmCallback* = proc(time: int, msg: string) {.gcsafe.}

  AppCallbacks* = ref object
    alarmEventCb*: ClockAlarmCallback

  Alarm* = ref object
    time: Moment
    msg: string

  Clock* = ref object
    alarms: seq[Alarm]
    appCallbacks: AppCallbacks

proc `$`*(alarm: Alarm): string =
  $(%*alarm)

proc new*(T: type Clock, appCallbacks: AppCallbacks): T =
  return Clock(alarms: newSeq[Alarm](), appCallbacks: appCallbacks)

proc getAlarms*(clock: Clock): seq[Alarm] =
  return clock.alarms

proc setAlarm*(clock: Clock, timeMillis: int, msg: string) =
  let newAlarm = Alarm(time: Moment.fromNow(milliseconds(timeMillis)), msg: msg)

  clock.alarms.add(newAlarm) # Add alarm to the clock's alarms sequence

  proc onAlarm(udata: pointer) {.gcsafe.} =
    try:
      if not isNil(clock.appCallbacks) and not isNil(clock.appCallbacks.alarmEventCb):
        clock.appCallbacks.alarmEventCb(timeMillis.int, newAlarm.msg)
    except Exception:
      error "Exception calling alarmEventCb", error = getCurrentExceptionMsg()

    for index, alarm in clock.alarms:
      if alarm.time == newAlarm.time:
        clock.alarms.del(index)
        break

  discard setTimer(newAlarm.time, onAlarm)
