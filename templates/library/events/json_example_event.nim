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
# 4. Modify the constructor to handle your event's specific parameters
# 5. Implement the required `$` method
#
# See additional TODO comments throughout the file for specific guidance.

import std/json
import ./json_base_event

# TODO: change the type name to `Json<YourEventName>Event`
# TODO: update the fields to match your event's data
type JsonExampleEvent* = ref object of JsonEvent
  exampleStr*: string
  exampleSeq: seq[string]

# TODO: change new() procedure to match your event type and its parameters
proc new*(T: type JsonExampleEvent, exampleStr: string, exampleSeq: seq[string]): T =
  return JsonExampleEvent(
    eventType: "example", exampleStr: exampleStr, exampleSeq: exampleSeq
  )

# TODO: Use your event type
method `$`*(jsonExample: JsonExampleEvent): string =
  $(%*jsonExample)
