#[
  Multi-threaded TCP server, borrowed from httpbeast
  https://github.com/dom96/httpbeast/blob/master/src/httpbeast.nim
]#
import asyncdispatch, asynchttpserver, nativesockets, streams, times, sim, strutils, tables, httpclient, selectors, net, os, osproc, deques, locks
from asyncnet import close
import ba0f3/logger

type
  FdKind = enum
    Server, Client, Dispatcher

  Data* = object
    kind: FdKind
    sendQueue*: string
    bytesSent: int

  Settings* = object
    port*: int
    bindAddr*: string
    numThreads*: int
    loggers*: seq[Logger]

  OnRequest = proc(selector: Selector[Data], client: SocketHandle, data: StringStream) {.gcsafe.}

template handleAccept() =
  let (client, address) = fd.SocketHandle.accept()
  if client == osInvalidSocket:
    let lastError = osLastError()
    if lastError.int32 == 24:
      warn("Ignoring EMFILE error: ", osErrorMsg(lastError))
      return
    raiseOSError(lastError)
  debug "Incoming connection from", fd=client.int, address=address
  setBlocking(client, false)
  selector.registerHandle(client, {Event.Read}, Data(kind: Client))

template handleClientClosure(selector: Selector[Data], fd: SocketHandle|int, inLoop=true) =
  let (address, _) = getPeerAddr(fd.SocketHandle, AF_INET)
  debug "Client disconnected, unregister handler", fd, address
  selector.unregister(fd)
  fd.SocketHandle.close()
  when inLoop:
    break
  else:
    return

proc processEvents(selector: Selector[Data], events: array[64, ReadyKey], count: int, onRequest: OnRequest) {.thread.} =
  for i in 0 ..< count:
    let
      fd = events[i].fd
      data: ptr Data = addr(selector.getData(fd))
    if Event.Error in events[i].events:
      if isDisconnectionError({SocketFlag.SafeDisconn}, events[i].errorCode):
        handleClientClosure(selector, fd)
      raiseOSError(events[i].errorCode)
    case data.kind:
    of Server:
      if Event.Read in events[i].events:
        handleAccept()
      else:
        assert false, "Only Read events are expected for the server"
    of Dispatcher:
      # Run the dispatcher loop.
      assert events[i].events == {Event.Read}
      asyncdispatch.poll(0)
    of Client:
      if Event.Read in events[i].events:
        const size = 256
        var buf: array[size, char]
        var data = newStringStream()
        while true:
          let ret = recv(fd.SocketHandle, addr buf[0], size, 0.cint)
          if ret == 0:
            handleClientClosure(selector, fd)
          if ret == -1:
            # Error!
            let lastError = osLastError()
            if lastError.int32 in {EWOULDBLOCK, EAGAIN}:
              break
            if isDisconnectionError({SocketFlag.SafeDisconn}, lastError):
              handleClientClosure(selector, fd)
            raiseOSError(lastError)
          # Write buffer to our data.
          data.writeData(addr buf[0], ret)
          if ret != size:
            # Assume there is nothing else for us right now and break.
            break
        if data.getPosition() != 0:
          data.setPosition(0)
          onRequest(selector, fd.SocketHandle, data)

      elif Event.Write in events[i].events:
          let leftover = data.sendQueue.len - data.bytesSent
          assert data.bytesSent <= data.sendQueue.len
          if leftover <= 0:
            break
          let ret = send(fd.SocketHandle, addr data.sendQueue[data.bytesSent], leftover, 0)
          if ret == -1:
            # Error!
            let lastError = osLastError()
            if lastError.int32 in {EWOULDBLOCK, EAGAIN}:
              break
            let e = getCurrentException()
            error "Error sending data", error=e.name, message=e.msg, hostname=c.hostname, port=c.port, lastError
            if isDisconnectionError({SocketFlag.SafeDisconn}, lastError):
              handleClientClosure(selector, fd)
            raiseOSError(lastError)
          data.bytesSent.inc(ret)
          if data.sendQueue.len == data.bytesSent:
            data.bytesSent = 0
            data.sendQueue.setLen(0)
            selector.updateHandle(fd.SocketHandle, {Event.Read})
      else:
        assert false

proc eventLoop(params: (Settings, OnRequest)) {.nimcall, gcsafe.} =
  let (settings, onRequest) = params

  for logger in settings.loggers:
    addHandler(logger)

  let
    selector = newSelector[Data]()
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
    let ret = selector.selectInto(-1, events)
    processEvents(selector, events, ret, onRequest)
    if unlikely(asyncdispatch.getGlobalDispatcher().callbacks.len > 0):
      asyncdispatch.poll(0)

proc runServer*(settings: Settings, onRequest: OnRequest) =
  when compileOption("threads"):
    let numThreads =
      if settings.numThreads == 0: countProcessors()
      else: settings.numThreads
  else:
    let numThreads = 1

  info "Starting", numThreads
  if numThreads > 1:
    when compileOption("threads"):
      var threads = newSeq[Thread[(Settings, OnRequest)]](numThreads)
      for i in 0 ..< numThreads:
        createThread(threads[i], eventLoop, (settings, onRequest))
      info "Listening", port=settings.port
      joinThreads(threads)
    else:
      assert false
  else:
    eventLoop((settings, onRequest))