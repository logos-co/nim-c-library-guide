{.pragma: exported, exportc, cdecl, raises: [].}
{.pragma: callback, cdecl, raises: [], gcsafe.}
{.passc: "-fPIC".}

import std/[options, atomics, os, net, locks]
import chronicles, chronos, chronos/threadsync, taskpools/channels_spsc_single, results
import ../ffi_types, ./inter_thread_communication/vcache_thread_request

type VCacheContext* = object
  thread: Thread[(ptr VCacheContext)]
  lock: Lock
  reqChannel: ChannelSPSCSingle[ptr VCacheThreadRequest]
  reqSignal: ThreadSignalPtr
    # to inform The VCache Thread (a.k.a TST) that a new request is sent
  reqReceivedSignal: ThreadSignalPtr
    # to inform the main thread that the request is rx by TST
  userData*: pointer
  eventCallback*: pointer
  eventUserdata*: pointer
  running: Atomic[bool] # To control when the thread is running

proc runVCache(ctx: ptr VCacheContext) {.async.} =
  ## This is the worker body. This runs the VCache instance
  ## and attends library user requests (stop, connect_to, etc.)

  var rm: ReliabilityManager

  while true:
    await ctx.reqSignal.wait()

    if ctx.running.load == false:
      break

    ## Trying to get a request from the libvcache requestor thread
    var request: ptr VCacheThreadRequest
    let recvOk = ctx.reqChannel.tryRecv(request)
    if not recvOk:
      error "vcache thread could not receive a request"
      continue

    let fireRes = ctx.reqReceivedSignal.fireSync()
    if fireRes.isErr():
      error "could not fireSync back to requester thread", error = fireRes.error

    ## Handle the request
    asyncSpawn VCacheThreadRequest.process(request, addr rm)

proc run(ctx: ptr VCacheContext) {.thread.} =
  ## Launch vcache worker
  waitFor runVCache(ctx)

proc createVCacheThread*(): Result[ptr SdsContext, string] =
  ## This proc is called from the main thread and it creates
  ## the VCache working thread.
  var ctx = createShared(VCacheContext, 1)
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

    return err("failed to create the VCache thread: " & getCurrentExceptionMsg())

  return ok(ctx)

proc destroyVCacheThread*(ctx: ptr VCacheContext): Result[void, string] =
  ctx.running.store(false)

  let signaledOnTime = ctx.reqSignal.fireSync().valueOr:
    return err("error in destroyVCacheThread: " & $error)
  if not signaledOnTime:
    return err("failed to signal reqSignal on time in destroyVCacheThread")

  joinThread(ctx.thread)
  ctx.lock.deinitLock()
  ?ctx.reqSignal.close()
  ?ctx.reqReceivedSignal.close()
  freeShared(ctx)

  return ok()

proc sendRequestToVCacheThread*(
    ctx: ptr VCacheContext,
    reqType: RequestType,
    reqContent: pointer,
    callback: VCacheCallBack,
    userData: pointer,
): Result[void, string] =
  let req = VCacheThreadRequest.createShared(reqType, reqContent, callback, userData)

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
    return err("Couldn't send a request to the vcache thread: " & $req[])

  let fireSyncRes = ctx.reqSignal.fireSync()
  if fireSyncRes.isErr():
    deallocShared(req)
    return err("failed fireSync: " & $fireSyncRes.error)

  if fireSyncRes.get() == false:
    deallocShared(req)
    return err("Couldn't fireSync in time")

  ## wait until the VCache Thread properly received the request
  let res = ctx.reqReceivedSignal.waitSync()
  if res.isErr():
    deallocShared(req)
    return err("Couldn't receive reqReceivedSignal signal")

  ## Notice that in case of "ok", the deallocShared(req) is performed by the VCache Thread in the
  ## process proc.
  ok()
