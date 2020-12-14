import macros, logging, os

export Level, log

var
  logger {.threadvar.}: ConsoleLogger
  fileLogger {.threadvar.}: RollingFileLogger

proc initLogger*(file: string = "", level = lvlDebug, fmtStr = "[$date $time] [$levelname] ")  =
  if logger != nil:
    return
  when defined(release):
    setLogFilter(lvlInfo)
  logger = newConsoleLogger(level, fmtStr=fmtStr)
  addHandler(logger)
  if file.len != 0:
    fileLogger = newRollingFileLogger(file, levelThreshold=level, fmtStr=fmtStr)
    addHandler(fileLogger)

macro log1(level: static[string], args: varargs[untyped]): untyped =
  result = newNimNode(nnkCall)
  result.add(newIdentNode("log"))
  result.add(newIdentNode(level))
  result.add newLit("\t")
  for i in 0..<args.len:
    let kind = args[i].kind
    if kind == nnkExprEqExpr:
      if args[i][1].kind == nnkIdent or args[i][1].kind == nnkCall:
        result.add newLit($args[i][0] & "=")
        result.add args[i][1]
      else:
        result.add newLit($args[i][0] & "=" & $args[i][1].toStrLit())
    elif kind == nnkStrLit:
      result.add args[i]
    elif kind == nnkIntLit:
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
  log1("lvlInfo", args)

template debug*(args: varargs[untyped]): untyped =
  log1("lvlDebug", args)

template notice*(args: varargs[untyped]): untyped =
  log1("lvlNotice", args)

template warn*(args: varargs[untyped]): untyped =
  log1("lvlWarn", args)

template error*(args: varargs[untyped]): untyped =
  log1("lvlError", args)

template fatal*(args: varargs[untyped]): untyped =
  log1("lvlFatal", args)

when isMainModule:
  addHandler(newConsoleLogger())
  let a = 1

  debug "debug", a, abc=1, a, b=bool(a)
  info "info", a, abc=1, a, b=a