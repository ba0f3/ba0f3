#[
  Multi-threaded TCP server, borrowed from httpbeast
  https://github.com/dom96/httpbeast/blob/master/src/httpbeast.nim
]#
import asyncdispatch, asynchttpserver, nativesockets, times, strutils, selectors, net, os, osproc, deques, locks
from asyncnet import close
import ba0f3/logger

type
  FdKind = enum
    Server, Client, Dispatcher

  Data* = object
    kind: FdKind
    lock: Lock
    sendQueue*: string
    recvQueue*: string
    bytesSent: int
    lastPacketReceived*: DateTime

  Settings* = object
    port*: int
    bindAddr*: string
    clientTimeoutInSeconds*: int = 60
    numThreads*: int
    loggers*: seq[Logger]

  Callback = proc(selector: Selector[Data], client: SocketHandle) {.gcsafe.}

template handleClientClosure(selector: Selector[Data], fd: SocketHandle|int) =
  if onDisconnect != nil:
    onDisconnect(selector, fd.SocketHandle)
  let data = addr(selector.getData(fd))
  data.lock.deinitLock()
  selector.unregister(fd)
  fd.SocketHandle.close()


proc processEvents(selector: Selector[Data], events: array[64, ReadyKey], count: int, clientList: var seq[SocketHandle], onRequest: Callback, onConnect: Callback, onDisconnect: Callback) {.thread.} =
  for i in 0 ..< count:
    let
      fd = events[i].fd
      data = addr(selector.getData(fd))
    if Event.Error in events[i].events:
      if isDisconnectionError({SocketFlag.SafeDisconn}, events[i].errorCode):
        handleClientClosure(selector, fd)
        continue
      raiseOSError(events[i].errorCode)
    case data.kind:
    of Server:
      if Event.Read in events[i].events:
        let (client, _) = fd.SocketHandle.accept()
        if client == osInvalidSocket:
          let lastError = osLastError()
          if lastError.int32 == 24: # Ignore EMFILE
            warn("Ignoring EMFILE error: ", osErrorMsg(lastError))
            return
          raiseOSError(lastError)
        setBlocking(client, false)
        var clientData = Data(
          kind: Client,
          lastPacketReceived: now()
        )
        clientData.lock.initLock()
        selector.registerHandle(client, {Event.Read}, clientData)
        clientList.add(client)
        if onConnect != nil:
          onConnect(selector, client)
      else:
        assert false, "Only Read events are expected for the server"
    of Dispatcher:
      # Run the dispatcher loop.
      assert events[i].events == {Event.Read}
      asyncdispatch.poll(0)
    of Client:
      if Event.Read in events[i].events:
        # Efficiently read data in chunks
        const chunkSize = 4096
        var
          buf: array[chunkSize, char]
          ret: int
        withLock(data.lock):
          while true:
            ret = recv(fd.SocketHandle, addr buf[0], chunkSize, 0.cint)
            if ret == 0:
              handleClientClosure(selector, fd)
              break
            elif ret == -1:
              # Error!
              let lastError = osLastError()
              if lastError.int32 in {EWOULDBLOCK, EAGAIN}:
                break
              if isDisconnectionError({SocketFlag.SafeDisconn}, lastError):
                handleClientClosure(selector, fd)
                break
              raiseOSError(lastError)

            data.lastPacketReceived = now()

            # Write buffer to our data.
            let origLen = data.recvQueue.len
            data.recvQueue.setLen(origLen + ret)
            for i in 0 ..< ret:
              data.recvQueue[origLen+i] = buf[i]
            if ret != chunkSize:
              # Assume there is nothing else for us right now and break.
              break
          if data.recvQueue.len > 0 and onRequest != nil:
            onRequest(selector, fd.SocketHandle)
          data.recvQueue.setLen(0)
      elif Event.Write in events[i].events:
        # Efficiently send data in chunks
        const sendChunkSize = 4096
        var leftover = data.sendQueue.len - data.bytesSent
        assert data.bytesSent <= data.sendQueue.len
        if leftover <= 0:
          break
        while leftover > 0:
          let chunkSize = min(leftover, sendChunkSize)
          let ret = send(fd.SocketHandle, addr data.sendQueue[data.bytesSent], chunkSize, 0)
          if ret == -1:
            # Error!
            let lastError = osLastError()
            if lastError.int32 in {EWOULDBLOCK, EAGAIN}:
              break
            let e = getCurrentException()
            error "Error sending data", lastError, error=e.name, message=e.msg
            if isDisconnectionError({SocketFlag.SafeDisconn}, lastError):
              handleClientClosure(selector, fd)
              break
            raiseOSError(lastError, "Error sending data")
          data.bytesSent.inc(ret)
          leftover.dec(ret)
          if ret != chunkSize:  # Assume no more data can be sent for now
            break
        if data.sendQueue.len == data.bytesSent:
          data.bytesSent = 0
          data.sendQueue.setLen(0)
          selector.updateHandle(fd.SocketHandle, {Event.Read})
      else:
        assert false, "Unexpected event for Client"

proc eventLoop(params: (Settings, Callback, Callback, Callback)) {.thread.} =
  let (settings, onRequest, onConnect, onDisconnect) = params

  for logger in settings.loggers:
    addHandler(logger)

  var
    selector = newSelector[Data]()
    clientList: seq[SocketHandle]
    server = newSocket()

  server.setSockOpt(OptReuseAddr, true)
  server.setSockOpt(OptReusePort, true)
  server.bindAddr(Port(settings.port), settings.bindAddr)
  server.listen()
  server.getFd().setBlocking(false)
  selector.registerHandle(server.getFd(), {Event.Read}, Data(kind: Server))


  let disp = getGlobalDispatcher()
  selector.registerHandle(getIoHandler(disp).getFd(), {Event.Read}, Data(kind: Dispatcher))

  var events: array[64, ReadyKey]
  while true:
    let ret = selector.selectInto(500, events)
    if ret > 0:
      processEvents(selector, events, ret, clientList, onRequest, onConnect, onDisconnect)
    elif settings.clientTimeoutInSeconds > 0 and not selector.isEmpty():
      var
        data: ptr Data
        t = now()
        duration = initDuration(seconds=settings.clientTimeoutInSeconds)
      for i in 0..<clientList.len:
        if selector.contains(clientList[i]):
          data = addr(selector.getData(clientList[i]))
          let timeout = t - data.lastPacketReceived
          if timeout > duration:
            debug "Closing inactive client", client=clientList[i].int, ping=timeout.inSeconds
            handleClientClosure(selector, clientList[i])
            break
        else:
          clientList.del(i)
          break
    if unlikely(asyncdispatch.getGlobalDispatcher().callbacks.len > 0):
        asyncdispatch.poll(0)

proc runServer*(settings: Settings, onRequest: Callback, onConnect: Callback = nil, onDisconnect: Callback, bJoinThreads = false) =
  when compileOption("threads"):
    let numThreads =
      if settings.numThreads == 0: countProcessors()
      else: settings.numThreads
  else:
    let numThreads = 0

  info "Listening", bindAddr=settings.bindAddr, port=settings.port, threads=numThreads
  if numThreads > 0:
    var threads = newSeq[Thread[(Settings, Callback, Callback, Callback)]](numThreads)
    for i in 0 ..< numThreads:
      createThread(threads[i], eventLoop, (settings, onRequest, onConnect, onDisconnect))

    if bJoinThreads:
      joinThreads(threads)
  else:
    eventLoop((settings, onRequest, onConnect, onDisconnect))
