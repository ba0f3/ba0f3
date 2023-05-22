from strutils import toHex

converter intToPointer*(x: int): pointer = cast[pointer](x)

proc `$`*(p: pointer): string = "0x" & cast[int](p).toHex()

template `+`*[T](p: ptr T, off: SomeInteger): pointer =
  cast[ptr type(p[])](cast[int](p) +% off.int)

template `+=`*[T](p: ptr T, off: SomeInteger) =
  p = p + off

template `-`*[T](p: ptr T, off: SomeInteger): pointer =
  cast[ptr type(p[])](cast[int](p) -% off.int)

template `-=`*[T](p: ptr T, off: SomeInteger) =
  p = p - off

template `+`*(p: pointer, off: SomeInteger): pointer =
  cast[pointer](cast[int](p) +% off.int)

template `+=`*(p: pointer, off: SomeInteger) =
  p = p + off

template `-`*(p: pointer, off: SomeInteger): pointer =
  cast[pointer](cast[int](p) -% off.int)

template `-=`*(p: pointer, off: SomeInteger) =
  p = p - off

template inc*[T](p: ptr T) =
  let size = sizeof(T)
  p = cast[ptr T](p + size)
