## This file contains the base message request type that will be handled.
## The requests are created by the main thread and processed by
## the VCache Thread.

import std/json, results
import chronos, chronos/threadsync
import ../../ffi_types, ./requests/[vcache_lifecycle_request, vcache_value_request]

type RequestType* {.pure.} = enum
  LIFECYCLE
  MESSAGE
  DEPENDENCIES

type VCacheThreadRequest* = object
  reqType: RequestType
  reqContent: pointer
  callback: VCacheCallBack
  userData: pointer

proc createShared*(
    T: type VCacheThreadRequest,
    reqType: RequestType,
    reqContent: pointer,
    callback: VCacheCallBack,
    userData: pointer,
): ptr type T =
  var ret = createShared(T)
  ret[].reqType = reqType
  ret[].reqContent = reqContent
  ret[].callback = callback
  ret[].userData = userData
  return ret

proc handleRes[T: string | void](
    res: Result[T, string], request: ptr VCacheThreadRequest
) =
  ## Handles the Result responses, which can either be Result[string, string] or
  ## Result[void, string].

  defer:
    deallocShared(request)

  if res.isErr():
    foreignThreadGc:
      let msg = "libvcache error: handleRes fireSyncRes error: " & $res.error
      request[].callback(
        RET_ERR, unsafeAddr msg[0], cast[csize_t](len(msg)), request[].userData
      )
    return

  foreignThreadGc:
    var msg: cstring = ""
    when T is string:
      msg = res.get().cstring()
    request[].callback(
      RET_OK, unsafeAddr msg[0], cast[csize_t](len(msg)), request[].userData
    )
  return

proc process*(
    T: type VCacheThreadRequest,
    request: ptr VCacheThreadRequest,
    rm: ptr ReliabilityManager,
) {.async.} =
  let retFut =
    case request[].reqType
    of LIFECYCLE:
      cast[ptr VCacheLifecycleRequest](request[].reqContent).process(rm)
    of VALUE:
      cast[ptr VCacheValueRequest](request[].reqContent).process(rm)

  handleRes(await retFut, request)

proc `$`*(self: VCacheThreadRequest): string =
  return $self.reqType
