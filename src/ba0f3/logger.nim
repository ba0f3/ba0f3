import macros, logging, os

export Level, Logger, log, addHandler, getHandlers, setLogFilter
var
  logger {.threadvar.}: ConsoleLogger
  fileLogger {.threadvar.}: FileLogger
  logLevel {.compileTime.} = lvlDebug

proc initLogger*(file: string = "", level = lvlDebug, fmtStr = "[$date $time] [$levelname]\t", bufSize = -1)  =
  if logger != nil:
    return
  logger = newConsoleLogger(level, fmtStr=fmtStr)
  if file.len != 0:
    fileLogger = newFileLogger(file, mode=fmAppend, levelThreshold=level, fmtStr=fmtStr, bufSize)
    addHandler(fileLogger)
  addHandler(logger)

macro setLogLevel*(lvl: static[Level]) =
  logLevel = lvl

macro logImpl(level: static[string], args: varargs[untyped]): untyped =
  result = newNimNode(nnkCall)
  result.add(newIdentNode("log"))
  result.add(newIdentNode(level))
  for i in 0..<args.len:
    let kind = args[i].kind
    if kind == nnkExprEqExpr:
      result.add newLit($args[i][0] & "=")
      result.add args[i][1]
    elif kind == nnkStrLit or kind == nnkIntLit:
      result.add args[i]
    else:
      result.add newLit(args[i].repr & "=")
      result.add args[i]
    if i > 0 and i < args.len - 1:
      result.add newLit(", ")
    elif i == 0 and args.len > 1:
      result.add newLit(" ")
  let line = lineInfoObj(args[0])
  result.add newLit(" [" & lastPathPart(line.filename) & ":" & $line.line & "]")

template info*(args: varargs[untyped]): untyped =
  when logLevel <= lvlInfo:
    when not compileOption("threads"):
      logImpl("lvlInfo", args)
    else:
      logImpl("lvlInfo", args, t=getThreadId())

template debug*(args: varargs[untyped]): untyped =
  when logLevel <= lvlDebug:
    when not compileOption("threads"):
      logImpl("lvlDebug", args)
    else:
      logImpl("lvlDebug", args, t=getThreadId())

template notice*(args: varargs[untyped]): untyped =
  when logLevel <= lvlNotice:
    when not compileOption("threads"):
      logImpl("lvlNotice", args)
    else:
      logImpl("lvlNotice", args, t=getThreadId())

template warn*(args: varargs[untyped]): untyped =
  when logLevel <= lvlWarn:
    when not compileOption("threads"):
      logImpl("lvlWarn", args)
    else:
      logImpl("lvlWarn", args, t=getThreadId())

template error*(args: varargs[untyped]): untyped =
  when logLevel <= lvlError:
    when not compileOption("threads"):
      logImpl("lvlError", args, stacktrace=getStackTrace())
    else:
      logImpl("lvlError", args, t=getThreadId(), stacktrace=getStackTrace())

template fatal*(args: varargs[untyped]): untyped =
  when logLevel <= lvlFatal:
    when not compileOption("threads"):
      logImpl("lvlFatal", args)
    else:
      logImpl("lvlFatal", args, t=getThreadId())

when isMainModule:
  addHandler(newConsoleLogger())

  let a = 1

  debug "debug", a, abc=1, a, b=bool(a)
  info "info", a, abc=1, a, b=a
