import os, ba0f3/sharedmem

type Arr = array[32, int]

let
  sm = initSharedMem("sharedmem", sizeof(Arr))
  arrPtr = cast[ptr Arr](sm.getMemPtr().mem)

if paramCount() != 1:
  quit("Usage: " & paramStr(0) & " read|write|close")

if paramStr(1) == "write":
  for i in 0..<arrPtr[].len:
    arrPtr[i] = i + 1

  while true:
    for i in 0..<arrPtr.len:
      arrPtr[i] = arrPtr[i] * 2
    sleep(2000)
elif paramStr(1) == "read":
  while true:
    echo arrPtr[]
    sleep(1000)
elif paramStr(1) == "close":
  sm.close()
else:
    quit("Usage: " & paramStr(0) & " read|write|close")