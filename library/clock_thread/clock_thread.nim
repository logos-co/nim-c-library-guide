# Clock Thread Manager
#
# This file defines the `ClockContext` and associated logic to manage the Clock thread.
# It sets up inter-thread communication via channels and signals, allowing the client
# thread to send requests to the Clock thread for processing.
#
# IMPLEMENTATION STEPS:
# 1. Rename this file to `<your_library_name>_thread.nim`
# 2. Remove Clock related imports and replace it with your library's equivalents
# 3. Rename `runClock` proc and adapt it to your library's types
# 4. Replace all instances of the word "clock" for your library's name, so that both the
#    types match your library's and the comments make sense.
#    It's recommended to replace "Clock" for YourLibrary and "clock" for yourLibrary, so
#    capitalization structures are preserved
#
# See additional TODO comments throughout the file for specific guidance.

{.pragma: exported, exportc, cdecl, raises: [].}
{.pragma: callback, cdecl, raises: [], gcsafe.}
{.passc: "-fPIC".}

import std/[options, atomics, os, net, locks]
import chronicles, chronos, chronos/threadsync, taskpools/channels_spsc_single, results
# TODO: replace clock related imports to your library's equivalents
import ../ffi_types, ./inter_thread_communication/clock_thread_request, ../../src/clock

# Context from the Clock thread, shared with the Client thread
type ClockContext* = object
  thread: Thread[(ptr ClockContext)] # The running thread that executes the Clock loop
  lock: Lock # Used to serialize access to the SP channel
  reqChannel: ChannelSPSCSingle[ptr ClockThreadRequest]
  reqSignal: ThreadSignalPtr # To notify the Clock Thread that a request is ready
  reqReceivedSignal: ThreadSignalPtr
    # To notify the Client thread that the request was received
  userData*: pointer
  eventCallback*: pointer
  eventUserdata*: pointer
  running: Atomic[bool] # Used to stop the Clock thread loop

# Main async loop of the Clock thread, processes incoming requests
# TODO: rename proc and change it to use your library's types
proc runClock(ctx: ptr ClockContext) {.async.} =
  ## This is the worker body. This runs the Clock instance
  ## and attends library user requests

  var clock: Clock

  while true:
    await ctx.reqSignal.wait()

    if ctx.running.load == false:
      break

    ## Trying to get a request from the libclock requestor thread
    var request: ptr ClockThreadRequest
    let recvOk = ctx.reqChannel.tryRecv(request)
    if not recvOk:
      error "clock thread could not receive a request"
      continue

    let fireRes = ctx.reqReceivedSignal.fireSync()
    if fireRes.isErr():
      error "could not fireSync back to requester thread", error = fireRes.error

    ## Handle the request
    asyncSpawn ClockThreadRequest.process(request, addr clock)

# Thread entrypoint wrapper to start the async runClock loop
proc run(ctx: ptr ClockContext) {.thread.} =
  ## Launch clock worker
  waitFor runClock(ctx)

# Initializes the Clock thread, sets up channels, signals, and launches the thread
proc createClockThread*(): Result[ptr ClockContext, string] =
  ## This proc is called from the Client thread and it creates
  ## the Clock working thread.
  var ctx = createShared(ClockContext, 1)
  ctx.reqSignal = ThreadSignalPtr.new().valueOr:
    return err("couldn't create reqSignal ThreadSignalPtr")
  ctx.reqReceivedSignal = ThreadSignalPtr.new().valueOr:
    return err("couldn't create reqReceivedSignal ThreadSignalPtr")
  ctx.lock.initLock()

  ctx.running.store(true)

  try:
    createThread(ctx.thread, run, ctx)
  except ValueError, ResourceExhaustedError:
    # and freeShared for typed allocations!
    freeShared(ctx)

    return err("failed to create the Clock thread: " & getCurrentExceptionMsg())

  return ok(ctx)

# Gracefully shuts down the Clock thread and releases resources
proc destroyClockThread*(ctx: ptr ClockContext): Result[void, string] =
  ctx.running.store(false)

  let signaledOnTime = ctx.reqSignal.fireSync().valueOr:
    return err("error in destroyClockThread: " & $error)
  if not signaledOnTime:
    return err("failed to signal reqSignal on time in destroyClockThread")

  joinThread(ctx.thread)
  ctx.lock.deinitLock()
  ?ctx.reqSignal.close()
  ?ctx.reqReceivedSignal.close()
  freeShared(ctx)

  return ok()

# Sends a request to the Clock thread, blocking until it is received
proc sendRequestToClockThread*(
    ctx: ptr ClockContext,
    reqType: RequestType,
    reqContent: pointer,
    callback: ClockCallBack,
    userData: pointer,
): Result[void, string] =
  let req = ClockThreadRequest.createShared(reqType, reqContent, callback, userData)

  # This lock is only necessary while we use a SP Channel and while the signalling
  # between threads assumes that there aren't concurrent requests.
  # Rearchitecting the signaling + migrating to a MP Channel will allow us to receive
  # requests concurrently and spare us the need of locks
  ctx.lock.acquire()
  defer:
    ctx.lock.release()

  ## Sending the request
  let sentOk = ctx.reqChannel.trySend(req)
  if not sentOk:
    deallocShared(req)
    return err("Couldn't send a request to the clock thread: " & $req[])

  let fireSyncRes = ctx.reqSignal.fireSync()
  if fireSyncRes.isErr():
    deallocShared(req)
    return err("failed fireSync: " & $fireSyncRes.error)

  if fireSyncRes.get() == false:
    deallocShared(req)
    return err("Couldn't fireSync in time")

  ## wait until the Clock Thread properly received the request
  let res = ctx.reqReceivedSignal.waitSync()
  if res.isErr():
    deallocShared(req)
    return err("Couldn't receive reqReceivedSignal signal")

  ## Notice that in case of "ok", the deallocShared(req) is performed by the Clock Thread in the
  ## process proc.
  ok()
