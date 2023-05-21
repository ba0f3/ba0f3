import macros, random, tables, strutils

converter toPointer*(x: int): pointer = cast[pointer](x)

proc fnv32a[T: string|openArray[char]|openArray[uint8]|openArray[int8]](data: T): int32 =
  result = -18652613'i32
  for b in items(data):
    result = result xor ord(b).int32
    result = result *% 16777619

var
  nameToPointer {.compileTime.} = initTable[string, uint]()
  nameToIdent {.compileTime.} = initTable[string, string]()
  seed {.compileTime.} = fnv32a(CompileTime & CompileDate) and 0x7FFFFFFF
  r {.compileTime.} = initRand(seed)

macro faddr*(body: untyped): untyped =
  let input = ($body.toStrLit).split(".")
  if input.len > 1:
    let desc = input[1]
    echo desc
  let name = input[0]
  if nameToPointer.hasKey(name):
    let address = nameToPointer[name]
    result = quote do:
      cast[pointer](`address`)
  elif nameToIdent.hasKey(name):
    result = ident(nameToIdent[name])


macro fptr*(body: untyped) : untyped =
  ## this marco will create a proc type based on input
  ## and then create a proc pointer to an address if specified
  if body.kind != nnkProcDef:
    return

  var
    name, procName: string
    isExported = false
  if body[0].kind == nnkIdent:
    name = $body[0]
  else:
    name = $body[0][1]
    isExported = true
  var suffix = "_" & $r.next()
  procName = "proc_" & name & suffix

  var
    typeSection = newNimNode(nnkTypeSection)
    typeDef = newNimNode(nnkTypeDef)
    aliasProc = newProc(ident(name))
    pragma = newNimNode(nnkPragma)
    tmplBody = newStmtList()
    funcAddress = body[6][0]
    tmplDef = newEmptyNode()
    tmplNameIdent: NimNode

  if (nameToPointer.hasKey(name)):
    echo name & " is already defined, this may causes hooking to wrong address"

  # pragma
  if body[4].kind == nnkPragma:
    pragma = body[4]
  pragma.add(ident("gcsafe"))

  if isExported:
    let aliasProcName = ident(name)
    aliasProcName.copyLineInfo(body)
    aliasProc.name = postfix(aliasProcName, "*")
    typeDef.add(postfix(ident(procName), "*"))
  else:
    typeDef.add(ident(procName))

  typeDef.add(newEmptyNode())
  typeDef.add(newNimNode(nnkProcTy)
    .add(body[3]) # FormalParams
    .add(pragma) # pragmas
  )
  result = newStmtList(typeSection.add(typeDef))

  aliasProc.params = body[3]
  aliasProc.addPragma(ident("inline"))
  aliasProc.addPragma(ident("gcsafe"))

  if body[6].kind == nnkStmtList:
    if funcAddress.kind == nnkIntLit:
      nameToPointer[name] = cast[uint](funcAddress.intVal)
    elif funcAddress.kind == nnkIdent:
      nameToIdent[name] = funcAddress.toStrLit.strVal

    aliasProc.body = newCall(
      newNimNode(nnkCast)
      .add(ident(procName))
      .add(funcAddress)
    )
    for param in body[3]:
      if param.kind == nnkIdentDefs:
        aliasProc.body.add(param[0])

  result.add(aliasProc)
  #echo treeRepr result
  echo repr result

when isMainModule:
  proc NI_Add(a: int, b: int): int = a + b
  proc A*(a: int, b: int): int {.fptr, cdecl.} = NI_Add
  proc B*(a: int, b: int): int {.fptr, cdecl.} = 123
  echo "NI_Add ", cast[int](NI_Add)
  echo "A ", cast[int](A)
  echo repr(faddr A)
  echo cast[int](NI_Add) == faddr A
  echo A(1, 2)
  echo B(1, 2)