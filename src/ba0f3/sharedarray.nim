 type
   SharedArray*[T] = ptr UncheckedArray[T]

proc initSharedArray*[T](size: int): SharedArray[T] =
  result = cast[SharedArray[T]](allocShared0(sizeof(T) * size))

proc deinit*[T](a: SharedArray[T]) {.inline.} = deallocShared(a)

proc resize*[T](a: SharedArray[T], newSize: int): SharedArray[T] =
  result = cast[SharedArray[T]](reallocShared(a, sizeof(T) * nsize))