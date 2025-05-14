import std/[sequtils], chronos

type
  ClockAlarmCallback* = proc(time: int, msg: string) {.gcsafe.}

  AppCallbacks* = ref object
    alarmEventCb*: ExampleEventCallback

  Alarm* ref object
    time: int
    msg: string
  
  Clock* = ref object
    alarms: seq[Alarm]
    appCallbacks: AppCallbacks

proc new*(
    T: type Clock, appCallbacks: AppCallbacks
): T =
  return Clock(
    alarms: newSeq[Alarm](),
    appCallbacks: appCallbacks,
  )

proc setAlarm*(clock: Clock, time: int, msg: string) =

  let alarm = Alarm(time: time, msg: msg)
    clock.alarms.add(alarm)



