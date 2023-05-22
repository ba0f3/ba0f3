import macros, strutils
import cptr

macro faddr*(body: untyped): untyped =
  let input = ($body.toStrLit).split(".")
  if input.len > 1:
    let desc = input[1]
    echo desc
  result = ident("fptr_value_" & input[0])

macro fptr*(body: untyped) : untyped =
  ## this marco will create a proc type based on input
  ## and then create a proc pointer to an address if specified
  if body.kind != nnkProcDef: return

  var
    name: string
    isExported = false

  if body[0].kind == nnkIdent:
    name = $body[0]
  else:
    name = $body[0][1]
    isExported = true

  if body[6].kind == nnkEmpty:
    raise newException(ValueError, "function pointer require a expr which converts to a pointer")

  let
    params = body[3]
    funcBody = body[6][0]
    procName = "fptr_proc_" & name


  var
    typeSection = newNimNode(nnkTypeSection)
    typeDef = newNimNode(nnkTypeDef)
    pragma = newNimNode(nnkPragma)
    tmplBody = newStmtList()

    tmplDef: NimNode
    tmplValueDef: NimNode
    tmplNameIdent: NimNode
    tmplValueIdent: NimNode
    procNameIdent: NimNode

  # pragma
  if body[4].kind == nnkPragma:
    pragma = body[4]
  pragma.add(ident("gcsafe"))

  procNameIdent = ident(procName)
  tmplNameIdent = ident(name)
  tmplNameIdent.copyLineInfo(body)
  tmplValueIdent = ident("fptr_value_" & name)

  if isExported:
    procNameIdent = postfix(procNameIdent, "*")
    tmplNameIdent = postfix(tmplNameIdent, "*")
    tmplValueIdent = postfix(tmplValueIdent, "*")

  typeDef.add(procNameIdent)
  typeDef.add(newEmptyNode())
  typeDef.add(newNimNode(nnkProcTy)
    .add(params) # FormalParams
    .add(pragma) # pragmas
  )
  tmplDef = nnkTemplateDef.newTree(
    tmplNameIdent,
    newEmptyNode(),
    newEmptyNode(),
    params,
    newEmptyNode(),
    newEmptyNode(),
    tmplBody
  )

  tmplValueDef = nnkTemplateDef.newTree(
    tmplValueIdent,
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    funcBody
  )

  tmplBody.add(newCall(
    newNimNode(nnkCast)
    .add(ident(procName))
    .add(funcBody)
  ))
  for param in body[3]:
    if param.kind == nnkIdentDefs:
      tmplBody[0].add(param[0])
  result = newStmtList(typeSection.add(typeDef))
  result.add(tmplValueDef)
  result.add(tmplDef)
  #echo treeRepr result
  #echo repr result

when isMainModule:
  proc NI_Add(a: int, b: int): int = a + b
  proc A*(a: int, b: int): int {.fptr, cdecl.} = NI_Add
  proc B*(a: int, b: int): int {.fptr, cdecl.} = cast[pointer](NI_Add)
  proc C*(a: int, b: int): int {.fptr, cdecl.} = 123
  echo "NI_Add => ", cast[int](NI_Add)
  #echo "A ", cast[int](A)
  echo "repr(faddr A) => ", repr(faddr A)
  echo "cast[int](NI_Add) == faddr A => ", cast[int](NI_Add) == faddr A
  echo "A(1, 2) => ", A(1, 2)
  echo "B(1, 2) => ", B(1, 2)
  echo "C(1, 2) => ", C(1, 2)