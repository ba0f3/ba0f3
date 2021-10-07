import logging, deques, locks

type
  DequeueLogger* = ref object of Logger
    maxSize: int
    queues*: Deque[string]
    lock: Lock

proc newDequeueLogger*(initialSize = 10, maxSize = -1, fmtStr = defaultFmtStr): DequeueLogger =
  new result
  result.maxSize = maxSize
  result.fmtStr = fmtStr
  result.queues = initDeque[string](initialSize)
  initLock(result.lock)

method log*(logger: DequeueLogger, level: Level, args: varargs[string, `$`]) =
  if level >= getLogFilter() and level >= logger.levelThreshold:
    let ln = substituteLog(logger.fmtStr, level, args)
    withLock logger.lock:
      if logger.maxSize > 0 and logger.queues.len >= logger.maxSize:
        var shrinkFirst = logger.queues.len - logger.maxSize  - 1
        logger.queues.shrink(shrinkFirst)
      logger.queues.addLast(ln)
