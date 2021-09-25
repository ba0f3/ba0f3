import times
when compileOption("threads"):
  import sharedtables
else:
  import tables

type
  Data = object
    allowance: float
    lastCheck*: float

when compileOption("threads"):
  type
    RateLimit*[T] = object
      rate: float
      period: float
      data: SharedTable[T, Data]
else:
  type
    RateLimit*[T] = object
      rate: float
      period: float
      data: Table[T, Data]

proc initRateLimit[T]*(rate: int, periodInSecondds = 1.0, initialSize = 32): RateLimit[T] =
  result = RateLimit[T](
    rate: rate.float,
    period: periodInSecondds
  )
  when compileOption("threads"):
    init(result.data, initialSize)
  else:
    result.data = initTable[T, Data](initialSize)

proc `=destroy`*[T](r: var RateLimit[T]) =
  when compileOption("threads"):
     deinitSharedTable(r.data)

template process(d: typed) =
  d.allowance += timePassed * (rate / period)
  if d.allowance > rate:
    d.allowance = rate
  if d.allowance < 1.0:
    ret = false
  else:
    d.allowance = 0.0
    ret = true

proc checkHit*[T](r: var RateLimit[T], key: T): bool =
  var
    timePassed: float
    ret: bool
  let
    t = epochTime()
    rate = r.rate
    period = r.period
  when compileOption("threads"):
    r.data.withKey(key) do(k: T, d: var Data, pairExists: var bool):
      if likely(pairExists):
        timePassed = t - d.lastCheck
        d.lastCheck = t
      else:
        d = Data(
          allowance: rate,
          lastCheck: t
        )
        pairExists = true
      process(d)
  else:
    if unlikely(not r.data.hasKey(key)):
      r.data[key] = Data(
        allowance: r.rate,
        lastCheck: t
      )
    timePassed = t - r.data[key].lastCheck
    r.data[key].lastCheck = t
    process(r.data[key])

  return ret

when isMainModule:
  import random
  randomize()
  var r = initRateLimit[int](rate=5)
  var hit = 0
  let t = epochTime()
  while true:
    if epochTime() - t >= 1.0:
      break
    if r.checkHit(1):
      inc(hit)
  assert hit == 5
