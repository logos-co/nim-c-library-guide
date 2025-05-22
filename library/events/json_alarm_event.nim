# JSON Example Event Implementation
#
# This file demonstrates how to implement a concrete event type derived from JsonEvent.
# For libraries with multiple event types, create separate files following this pattern
# for each event type.
#
# IMPLEMENTATION STEPS:
# 1. Rename this file to `json_<your_event_name>_event.nim`
# 2. Rename the type to `Json<YourEventName>Event`
# 3. Update the fields to match your event's data structure
# 4. Modify the new() procedure to handle your event's specific parameters
# 5. Implement the required `$` method
#
# See additional TODO comments throughout the file for specific guidance.

import std/json, chronos
import ./json_base_event

# TODO: change the type name to `Json<YourEventName>Event`
# TODO: update the fields to match your event's data
type JsonAlarmEvent* = ref object of JsonEvent
  time: int64 # time in epoch
  msg: string

# TODO: change new() procedure to match your event type and its parameters
proc new*(T: type JsonAlarmEvent, time: int64, msg: string): T =
  return JsonAlarmEvent(eventType: "clock_alarm", time: time, msg: msg)

# TODO: Use your event type
method `$`*(alarmEvent: JsonAlarmEvent): string =
  $(%*alarmEvent)
