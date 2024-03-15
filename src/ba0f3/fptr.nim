import macros, random, strutils

converter toPointer*(x: int): pointer = cast[pointer](x)

macro faddr*(body: untyped): untyped =
  let input = ($body.toStrLit).split(".")
  if input.len > 1:
    let desc = input[1]
    echo desc
  let name = ident("fptr_var_" & input[input.len - 1])
  result = quote do:
    addr `name`

macro fptr*(body: untyped) : untyped =
  ## this marco will create a proc type based on input
  ## and then create a proc pointer to an address if specified
  if body.kind != nnkProcDef:
    return

  var
    name, ptrName, procName: string
    isExported = false
  if body[0].kind == nnkIdent:
    name = $body[0]
  else:
    #[
      #echo treeRepr body[0]
    if body[0].kind == nnkAccQuoted:
      name = $body[0][0]
    else:
      name = $body[0][1]
    ]#
    name = $body[0][1]
    isExported = true
  procName = "fptr_proc_" & name
  ptrName = "fptr_var_" & name

  var
    typeSection = newNimNode(nnkTypeSection)
    typeDef = newNimNode(nnkTypeDef)
    varSection = newNimNode(nnkVarSection)
    identDef = newNimNode(nnkIdentDefs)
    aliasProc = newProc(ident(name))
    pragma = newNimNode(nnkPragma)

  typeSection.add(typeDef)
  varSection.add(identDef)

  # pragma
  if body[4].kind == nnkPragma:
    pragma = body[4]
  pragma.add(ident("gcsafe"))

  if isExported:
    typeDef.add(postfix(ident(procName), "*"))
  else:
    typeDef.add(ident(procName))
  typeDef.add(newEmptyNode())
  typeDef.add(newNimNode(nnkProcTy)
    .add(body[3]) # FormalParams
    .add(pragma) # pragmas
  )
  result = newStmtList(typeSection)

  if body[6].kind == nnkStmtList and body[6][0].kind == nnkIntLit:
    if isExported:
      identDef.add(postfix(ident(ptrName), "*"))
      let procName = ident(name)
      procName.copyLineInfo(body)
      aliasProc.name = postfix(procName, "*")
    else:
      let ptrName = ident(ptrName)
      ptrName.copyLineInfo(body)
      identDef.add(ptrName)


    identDef.add(newEmptyNode())
    identDef.add(newNimNode(nnkCast)
      .add(ident(procName))
      .add(body[6][0])
    )

    var aliasProcBody = newCall(ident(ptrName))
    for param in body[3]:
      if param.kind == nnkIdentDefs:
        aliasProcBody.add(param[0])

    aliasProc.params = body[3]
    aliasProc.addPragma(ident("inline"))
    aliasProc.body = aliasProcBody

    result.add(varSection)
    result.add(aliasProc)
    #echo treeRepr result

when isMainModule:
  proc NI_Add(a: int, b: int): int = a + b
  proc A(a: int, b: int): int {.fptr, cdecl.} = 123
  proc A(a: float, b: float): float {.fptr, cdecl.} = 124

  echo repr(faddr A.NI_Add)