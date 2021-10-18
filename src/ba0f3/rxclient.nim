import std/net, os, ba0f3/logger, streams, locks
export Port

when not compileOption("threads"):
  {.error: "This module requires `--threads:on` switch".}

type
  RxCallback = proc(c: RxClient) {.gcsafe.}

  RxClient* = ref object of RootObj
    hostname: string
    port: Port
    sock: Socket
    sendChan: ptr Channel[string]
    recvChan: ptr Channel[string]
    isRunning: bool
    isConnected: bool
    bufferSize: int
    retryDelay: int
    threads: array[2, Thread[(RxClient, seq[Logger])]]
    onConnect: RxCallback
    onReceiving: RxCallback
    lock: Lock

proc newRxClient*(hostname: string, port: Port, onConnect, onReceiving: RxCallback = nil, bufferSize = 1024, retryDelay = 2000): RxClient =
  new(result)
  result.hostname = hostname
  result.port = port
  result.bufferSize = bufferSize
  result.retryDelay = retryDelay
  result.sendChan = cast[ptr Channel[string]](allocShared0(sizeof(Channel[string])))
  result.recvChan = cast[ptr Channel[string]](allocShared0(sizeof(Channel[string])))
  result.onConnect = onConnect
  result.onReceiving = onReceiving
  initLock(result.lock)

proc connect(c: RxClient) =
  withLock(c.lock):
    while unlikely(not c.isConnected):
      debug "Connecting to server", hostname=c.hostname, port=c.port
      if c.sock != nil:
        c.sock.close()
      c.sock = newSocket()
      try:
        c.sock.connect(c.hostname, c.port)
        if c.onConnect != nil:
          c.onConnect(c)
        c.isConnected = true
        break
      except:
        let e = getCurrentException()
        error "Connection failed, retrying", error=e.name, message=e.msg, hostname=c.hostname, port=c.port
        sleep(c.retryDelay)

proc recvThread(params: (RxClient, seq[Logger])) {.thread.} =
  let (c, loggers) = params
  for logger in loggers:
    addHandler(logger)

  while c.isRunning:
    c.connect()
    try:
      if c.onReceiving != nil:
        c.onReceiving(c)
      else:
        var
          buffer = newString(c.bufferSize)
          ret = c.sock.recv(buffer.cstring, c.bufferSize)
        if ret < 0:
          debug "Error occurred while receiving", ret
          c.isConnected = false
        elif ret == 0:
          debug "Server closed connection", ret
          c.isConnected = false
        else:
          buffer.setLen(ret)
          c.recvChan[].send(buffer)
    except:
      c.isConnected = false
      let e = getCurrentException()
      error "Error receiving data", error=e.name, message=e.msg, hostname=c.hostname, port=c.port
    sleep(10)


proc sendThread(params: (RxClient, seq[Logger])) {.thread.} =
  let (c, loggers) = params
  for logger in loggers:
    addHandler(logger)
  var message: string

  while c.isRunning:
    c.connect()
    try:
      message = c.sendChan[].recv()
      c.sock.send(message)
    except:
      c.isConnected = false
      let e = getCurrentException()
      error "Error sending data", error=e.name, message=e.msg, hostname=c.hostname, port=c.port
    sleep(10)

proc open*(c: RxClient) =
  c.sendChan[].open()
  c.recvChan[].open()
  c.isRunning = true

  createThread(c.threads[0], recvThread, (c, getHandlers()))
  createThread(c.threads[1], sendThread, (c, getHandlers()))

proc close*(c: RxClient) =
  c.sendChan[].close()
  c.recvChan[].close()
  c.isRunning = false
  c.isConnected = false
  deinitLock(c.lock)

proc recv*(c: RxClient, cb: proc(msg: string)): bool  {.discardable.} =
  let (hasData, message) = c.recvChan[].tryRecv()
  if hasData:
    cb(message)
  return hasData

proc send*(c: RxClient, data: string): bool {.discardable.} =
  return c.sendChan[].trySend(data)