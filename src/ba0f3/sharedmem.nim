import posix

type
  SharedMemPtr = object
    mem*: pointer
    size: int

  SharedMem = object
    filename: string
    fd: cint
    size: int

template raiseOsErr() =
  raise newException(OSError, $strerror(errno))

proc initSharedMem*(filename: string, size: int, readOnly = false, mode = 400.Mode): SharedMem =
  var fFlag = if readOnly: O_RDONLY else: O_RDWR

  result.filename = filename
  result.size = size

  var ret = shm_open(filename, fFlag, mode) # try to open first without create, test if file exist
  if ret < 0:
    if errno == 2: # file does not exists
      ret = shm_open(filename, fFlag or O_CREAT, mode)
      if ret < 0:
        raiseOsErr()

      # allocate data for the first time
      var dummy = alloc0(size)
      defer: dealloc(dummy)
      let bytesWrote = write(ret, dummy, size)

      if bytesWrote < 0:
        raiseOsErr()
    else:
      raiseOsErr()
  result.fd = ret

proc close*(sm: SharedMem) =
  if shm_unlink(sm.filename) != 0:
    raiseOsErr()

proc getMemPtr*(sm: SharedMem): SharedMemPtr =
  result.size = sm.size
  result.mem = mmap(nil, sm.size, PROT_READ or PROT_WRITE, MAP_SHARED, sm.fd, 0)
  if result.mem == cast[pointer](MAP_FAILED):
    raiseOsErr()

proc `=destroy`(smp: var SharedMemPtr) =
  echo "=destroy SharedMemPtr"
  if munmap(smp.mem, smp.size) != 0:
    raiseOsErr()
