import macros, os, strutils
from cptr import intToPointer

macro faddr*(body: untyped): untyped =
  let input = ($body.toStrLit).split(".")

  var name: NimNode
  if input.len == 2:
    name = ident("fptr_var_" & input[0] & "_" & input[input.len - 1])
  else:
    name = ident("fptr_var_" & input[input.len - 1])
  result = quote do:
    addr `name`
  echo repr result

macro fptr*(body: untyped) : untyped =
  ## this marco will create a proc type based on input
  ## and then create a proc pointer to an address if specified
  if body.kind != nnkProcDef or body[6].kind == nnkEmpty:
    return

  let
    moduleName = lineInfoObj(body).filename.splitfile().name
    isExported = if body[0].kind == nnkIdent: true else: false
    name = if isExported: $body[0] else: $body[0][1]
    params = body[3]
    funcBody = body[6][0]

  var
    procName = ident("fptr_proc_" & name)
    varName = ident("fptr_var_" & name)
    varName2 = ident("fptr_var_" & modulename & "_" & name)

    typeSection = newNimNode(nnkTypeSection)
    typeDef = newNimNode(nnkTypeDef)
    varSection = newNimNode(nnkVarSection)
    identDef = newNimNode(nnkIdentDefs)
    identDef2 = newNimNode(nnkIdentDefs)
    ident2: NimNode
    aliasProc = newProc(ident(name))
    pragma = newNimNode(nnkPragma)

  typeSection.add(typeDef)
  varSection.add(identDef)

  # pragma
  if body[4].kind == nnkPragma:
    pragma = body[4]
  pragma.add(ident("gcsafe"))

  if isExported:
    typeDef.add(postfix(procName, "*"))
  else:
    typeDef.add(procName)
  typeDef.add(newEmptyNode())
  typeDef.add(newNimNode(nnkProcTy)
    .add(params) # FormalParams
    .add(pragma) # pragmas
  )

  var aliasProcBody = newCall(varName)

  if isExported:
    identDef.add(postfix(varName, "*"))
    varName2 = postfix(varName2, "*")
    let procName = ident(name)

    aliasProc.name = postfix(procName, "*")
  else:
    identDef.add(varName)

  procName.copyLineInfo(body)
  varName.copyLineInfo(body)
  varName2.copyLineInfo(body)

  identDef.add(newEmptyNode())
  identDef.add(newNimNode(nnkCast)
    .add(procName)
    .add(funcBody)
  )

  #identDef2 = identDef.copy()
  #identDef2[0] = varName2
  identDef2.add(varName2)
  identDef2.add(newEmptyNode())
  identDef2.add(varName)
  varSection.add(identDef2)


  for param in params:
    if param.kind == nnkIdentDefs:
      aliasProcBody.add(param[0])

  aliasProc.params = params
  aliasProc.addPragma(ident("inline"))
  aliasProc.body = aliasProcBody

  result = newStmtList(typeSection)
  result.add(varSection)
  result.add(aliasProc)
  #echo treeRepr result
  echo repr result

when isMainModule:
  proc NI_Add(a: int, b: int): int = a + b
  proc A(a: int, b: int): int {.fptr, cdecl.} = 123
  proc A(a: float, b: float): float {.fptr, cdecl.} = 124

  echo repr(faddr A.NI_Add)