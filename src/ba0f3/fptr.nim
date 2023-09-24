import macros

converter toPointer*(x: int): pointer = cast[pointer](x)

template fptrAddr*(address: int) {.pragma.}
template fptrVar*(name: typed): string {.pragma.}

macro faddr*(proctyp: typed): untyped =
  ## this macros will returns function address

  let pragmas = getImpl(proctyp).pragma
  for pragma in pragmas:
    if pragma.kind == nnkExprColonExpr and $pragma[0] == "fptrAddr":
      result = pragma[1]
      break

macro fvar*(proctyp: typed): untyped =
  ## this macros will returns a pointer to variable that contains function address

  let pragmas = getImpl(proctyp).pragma
  #echo treeRepr pragmas
  for pragma in pragmas:
    if pragma.kind == nnkExprColonExpr and $pragma[0] == "fptrVar":
      result = newDotExpr(pragma[1], ident("addr"))
      break

macro fptr*(procdef: untyped) : untyped =
  ## this marco will create a proc type based on input
  ## and then create a proc pointer to an address if specified

  if procdef.kind != nnkProcDef:
    raise newException(ValueError, "function pointer requires a proc")
  var
    name: string
    isExported = false
  if procdef[0].kind == nnkIdent:
    name = $procdef[0]
  else:
    name = $procdef[0][1]
    isExported = true
  var ptrName = genSym(nskVar, "fptr_var")

  var
    aliasProc = newProc(ident(name))
    pragma = newNimNode(nnkPragma)


  # pragma
  if procdef[4].kind == nnkPragma:
    pragma = procdef[4]
  pragma.add(ident("gcsafe"))


  result = newStmtList()

  var procTy = newNimNode(nnkProcTy)
    .add(procdef[3]) # FormalParams
    .add(pragma) # pragmas

  if procdef.body.kind != nnkStmtList or procdef.body[0].kind notin [nnkIntLit, nnkInt32Lit, nnkInt64Lit]:
    raise newException(ValueError, "fptr function pointer requires an address assigned")
  if isExported:
    let procName = ident(name)
    procName.copyLineInfo(procdef)
    aliasProc.name = postfix(procName, "*")
  else:
    ptrName.copyLineInfo(procdef)
  let addrNode = procdef[6][0]

  aliasProc.params = procdef[3]
  aliasProc.addPragma(ident("inline"))
  aliasProc.addPragma(newColonExpr(ident("fptrAddr"), procdef.body[0]))
  aliasProc.addPragma(newColonExpr(ident("fptrVar"), ptrName))

  result.add quote do:
    var `ptrName` = cast[`procTy`](`addrNode`)

  var callVarPtr = newCall(ptrName)
  for param in procdef[3]:
    if param.kind == nnkIdentDefs:
      callVarPtr.add(param[0])
  aliasProc.body.add(callVarPtr)

  result.add(aliasProc)
  #echo treeRepr result
  #echo repr result

when isMainModule:
  #proc NI_Add(a: int, b: int): int = a + b
  proc A1(a: int, b: int): int {.fptr, cdecl.} = 0xDEADBEEF
  proc A2(a: float, b: float): float {.fptr, cdecl.} = 0xC0FFEE
  var
    address = faddr A1
    ptrVar = fvar A2
  echo ptrVar[](0.0, 0.0)
  echo address

  #echo repr(faddr A.NI_Add)