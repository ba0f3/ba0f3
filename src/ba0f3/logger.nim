import macros, logging, os

export Level, Logger, log, addHandler, getHandlers

var
  logger {.threadvar.}: ConsoleLogger
  fileLogger {.threadvar.}: FileLogger

proc initLogger*(file: string = "", level = lvlDebug, fmtStr = "[$date $time] [$levelname] ")  =
  if logger != nil:
    return
  logger = newConsoleLogger(level, fmtStr=fmtStr)
  if file.len != 0:
    when not defined(release):
      fileLogger = newFileLogger(file, mode=fmAppend, levelThreshold=level, fmtStr=fmtStr, bufSize=0)
    else:
      fileLogger = newFileLogger(file, mode=fmAppend, levelThreshold=level, fmtStr=fmtStr)
    addHandler(fileLogger)
  addHandler(logger)

macro log1(level: static[string], args: varargs[untyped]): untyped =
  result = newNimNode(nnkCall)
  result.add(newIdentNode("log"))
  result.add(newIdentNode(level))
  result.add newLit("\t")
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
  when not compileOption("threads"):
    log1("lvlInfo", args)
  else:
    log1("lvlInfo", args, t=getThreadId())

template debug*(args: varargs[untyped]): untyped =
  when not compileOption("threads"):
    log1("lvlDebug", args)
  else:
    log1("lvlDebug", args, t=getThreadId())

template notice*(args: varargs[untyped]): untyped =
  when not compileOption("threads"):
    log1("lvlNotice", args)
  else:
    log1("lvlNotice", args, t=getThreadId())

template warn*(args: varargs[untyped]): untyped =
  when not compileOption("threads"):
    log1("lvlWarn", args)
  else:
    log1("lvlWarn", args, t=getThreadId())

template error*(args: varargs[untyped]): untyped =
  when not compileOption("threads"):
    log1("lvlError", args, stacktrace=getStackTrace())
  else:
    log1("lvlError", args, t=getThreadId(), stacktrace=getStackTrace())

template fatal*(args: varargs[untyped]): untyped =
  when not compileOption("threads"):
    log1("lvlFatal", args)
  else:
    log1("lvlFatal", args, t=getThreadId())

when isMainModule:
  addHandler(newConsoleLogger())

  let a = 1

  debug "debug", a, abc=1, a, b=bool(a)
  info "info", a, abc=1, a, b=a
