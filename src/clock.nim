import chronos, std/json, chronicles

type
  ClockAlarmCallback* = proc(time: Moment, msg: string) {.gcsafe.}

  AppCallbacks* = ref object
    alarmHandler*: ClockAlarmCallback

  Alarm* = ref object
    time: Moment
    msg: string
    createdAt: Moment

  Clock* = ref object
    alarms: seq[Alarm]
    appCallbacks: AppCallbacks

proc `$`*(alarm: Alarm): string =
  let jsonNode =
    %*{
      "time": alarm.time.epochSeconds(),
      "msg": alarm.msg,
      "createdAt": alarm.createdAt.epochSeconds(),
    }
  $jsonNode

proc new*(T: type Clock, appCallbacks: AppCallbacks): T =
  return Clock(alarms: newSeq[Alarm](), appCallbacks: appCallbacks)

proc getAlarms*(clock: Clock): seq[Alarm] =
  return clock.alarms

proc setAlarm*(clock: Clock, timeMillis: int, msg: string) =
  let time = Moment.fromNow(milliseconds(timeMillis))
  let newAlarm = Alarm(time: time, msg: msg, createdAt: Moment.now())

  clock.alarms.add(newAlarm) # Add alarm to the clock's alarms sequence

  proc onAlarm(udata: pointer) {.gcsafe.} =
    try:
      if not isNil(clock.appCallbacks) and not isNil(clock.appCallbacks.alarmHandler):
        clock.appCallbacks.alarmHandler(time, newAlarm.msg)
    except Exception:
      error "Exception calling alarmHandler", error = getCurrentExceptionMsg()

    for index, alarm in clock.alarms:
      if alarm.time == newAlarm.time:
        clock.alarms.del(index)
        break

  discard setTimer(newAlarm.time, onAlarm)
