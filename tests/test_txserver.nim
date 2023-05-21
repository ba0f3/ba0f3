import selectors, streams, nativesockets, ba0f3/[logger, txserver]

initLogger()

proc processClient(selector: Selector[Data], client: SocketHandle, input: StringStream, inputLen: int) {.thread.} =
  if selector != nil and client in selector:
    let data: ptr Data = addr(selector.getData(client))
    data.sendQueue.add(input.readAll())
    selector.updateHandle(client, {Event.Read, Event.Write})

let settings = Settings(
  port: 4444,
  bindAddr: "localhost",
  numThreads: 10,
  loggers: getHandlers()
)

runServer(settings, processClient)