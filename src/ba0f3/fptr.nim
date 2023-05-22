import macros, os, strutils
import cptr

macro faddr*(body: untyped): untyped =
  let input = ($body.toStrLit).split(".")

  var name = input[input.len - 1]
  if input.len == 2:
    name = "fptr_value_" & input[0] & "_" & name
  else:
    name = "fptr_value_" & name
  result = newCall(
    "addr",
    ident(name)
  )
  #echo repr result


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
    moduleName = lineInfoObj(body).filename.splitfile().name

  #var returnType = $params[0].toStrLit
  #if returnType == "":
  #  returnType = "void"s
  #echo "returnType ", returnType

  var
    typeSection = newNimNode(nnkTypeSection)
    typeDef = newNimNode(nnkTypeDef)
    pragma = newNimNode(nnkPragma)
    tmplBody = newStmtList()

    tmplDef: NimNode
    varValueDef: NimNode
    varValueWithModuleDef: NimNode
    tmplNameIdent: NimNode
    tmplValueIdent: NimNode
    tmplValueWithModuleIdent: NimNode
    procNameIdent: NimNode

  # pragma
  if body[4].kind == nnkPragma:
    pragma = body[4]
  pragma.add(ident("gcsafe"))

  procNameIdent = ident(procName)
  tmplNameIdent = ident(name)
  tmplValueIdent = ident("fptr_value_" & name)
  tmplValueWithModuleIdent = ident("fptr_value_" & moduleName & "_" & name)

  procNameIdent.copyLineInfo(body)
  tmplNameIdent.copyLineInfo(body)
  tmplValueWithModuleIdent.copyLineInfo(body)

  if isExported:
    procNameIdent = postfix(procNameIdent, "*")
    tmplNameIdent = postfix(tmplNameIdent, "*")
    tmplValueIdent = postfix(tmplValueIdent, "*")
    tmplValueWithModuleIdent = postfix(tmplValueWithModuleIdent, "*")

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

  tmplBody.add(newCall(
    newNimNode(nnkCast)
    .add(ident(procName))
    .add(funcBody)
  ))

  for param in body[3]:
    if param.kind == nnkIdentDefs:
      tmplBody[0].add(param[0])


  varValueDef = nnkVarSection.newTree(
    nnkIdentDefs.newTree(
      tmplValueIdent,
      newEmptyNode(),
      funcBody
    )
  )
  varValueWithModuleDef = varValueDef[0].copy()

  varValueWithModuleDef[0] = tmplValueWithModuleIdent
  varValueDef.add(varValueWithModuleDef)

  result = newStmtList(typeSection.add(typeDef))
  result.add(varValueDef)
  #result.add(varValueWithModuleDef)
  result.add(tmplDef)
  #echo treeRepr result
  #echo repr result

