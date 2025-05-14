import std/[sequtils]

type
  AppCallbacks* = ref object
    exampleEventCb*: ExampleEventCallback

  VCacheEventCallback* = proc(value: int, history: seq[int]) {.gcsafe.}

  VCache* = ref object
    value: int
    history: seq[int]
    historySizeLimit: uint
    appCallbacks: AppCallbacks

proc new*(
    T: type VCache, value: int, historySizeLimit: uint, appCallbacks: AppCallbacks
): T =
  return VCache(
    value: value,
    history: @[value],
    historySizeLimit: historySizeLimit,
    appCallbacks: appCallbacks,
  )

proc setValue*(vcache: VCache, value: int) =
  vcache.value = value

  if vcache.history.len == historySizeLimit:
    vcache.history.delete(0) # Remove the first (oldest) element

  vcache.history.add(value)

  if value mod 5 == 0:
    if not vcache.appCallbacks.exampleEventCb.isNil():
      vcache.appCallbacks.exampleEventCb(value, vcache.history)

proc getValue*(vcache: VCache) =
  return vcache.value

proc getHistory*(vcache: VCache) =
  return vcache.history
