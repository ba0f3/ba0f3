import ba0f3/fptr

proc NI_Add1(a: int, b: int): int = a + b
proc add*(a: int, b: int): int {.fptr, cdecl.} = NI_Add1