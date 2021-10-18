import os, ba0f3/[logger, rxclient]

initLogger()


let conn = newRxClient("localhost", Port(4444), bufferSize = 4, onConnect = proc(c: RxClient) =
  echo "onConnect"
)
conn.open()


var stop: bool

while not stop:
  conn.recv(proc(msg: string) =
    echo "RECV: ", msg
    if msg == "quit":
      echo "Quiting.."
      conn.close()
      stop = true
  )
  sleep(10)
