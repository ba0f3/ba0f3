import macros, tables, strutils

{.experimental: "dotOperators".}

type
  C* = object
    header: string

const manglingType = {
  "bool": 'b',
  "byte": '1',
  "char": 'c',
  "string": 'Z',
  "cstring": 'v',
  "int": 'i',
  "int8": '2',
  "int16": 'w',
  "int32": 'd',
  "int64": 'I',
  "uint": 'u',
  "uint8": '3',
  "uint16": 'W',
  "uint32": 'D',
  "uint64": 'U',
  "float64": 'F',
  "float32": 'f'
}.toTable

proc includec*(c: typedesc[C], header: string): C {.compileTime.} =
  result.header = header

macro exec*(s: NimNode) =
  result = s

macro makeProc*(c: static[C], name: string, args: varargs[untyped]): untyped =
  var
    definedProcs {.global.}: seq[string]
    nameMangling = $name & "_"
    returnType = "int"
  #nameMangling &= "v" # return type, void for now
  result = newStmtList()
  for i in 0..<args.len:
    let kind = getTypeInst(args[i]).repr
    if i == 0:
      if kind.startsWith("typeDesc"):
        let
          start = kind.find('[') + 1
          stop = kind.find(']') - 1
        returnType = kind[start..stop]
        nameMangling &= manglingType[returnType]
        continue
      else:
        nameMangling &= "v"

    if kind.startsWith("ptr") or kind == "pointer":
      nameMangling &= 'v'
    else:
      nameMangling &= manglingType[kind]
  if nameMangling in definedProcs:
    return

  definedProcs.add(nameMangling)


  var params: seq[NimNode]
  # TODO: handle return type
  if returnType.len == 0:
    params.add(newEmptyNode())
  else:
    params.add(ident(returnType))

  var i = 0
  for arg in items(args):
    let
      kind = getTypeInst(arg).repr
      paramName = ident("a" & $i)
    inc(i)
    if i == 0 and kind.startsWith("typeDesc"):
      continue

    var paramKind: NimNode
    case kind
    of "string", "cstring":
      paramKind = ident("cstring")
    else:
      if kind.startsWith("ptr") or kind == "pointer":
        paramKind = ident("pointer")
      else:
        paramKind = ident(kind)
    params.add(newIdentDefs(paramName, paramKind))

  #echo nameMangling
  var pragmas = newNimNode(nnkPragma)
  pragmas.add(ident("importc"))
  pragmas.add(newNimNode(nnkExprColonExpr).
    add(ident("header")).
    #add(c)
    add(newStrLitNode(c.header))
  )
  #result = newProc(postfix(ident($name), "*"), params, newEmptyNode(), nnkProcDef, pragmas)
  result = newProc(ident($name), params, newEmptyNode(), nnkProcDef, pragmas)
  #echo treeRepr result
  #echo repr result

macro call*(retval: typed, name: string, args: varargs[untyped]) =
  echo getTypeInst(retval).repr
  result = newCall(ident($name))
  for arg in items(args):
    #echo arg.kind
    case arg.kind
    #of nnkSym:
    #  continue
    of nnkStrLit:
      result.insert(result.len, newDotExpr(arg, ident("cstring")))
    else:
      result.insert(result.len, arg)
  result = newAssignment(retval, result)
  #echo treeRepr result
  #echo repr result

template `.`*(c: static[C], name: untyped, args: varargs[typed]): typed =
  makeProc(c, astToStr(name), args)

  var a: int
  call(a, astToStr(name), args)
  return a


#template call_ret*(T: typed, body: untyped): void =
#  var ret: T
#  proc inner() {.closure.} =
#    ret = body
#  return ret


template `=`*(a: untyped) =
  discard

when isMainModule:
  const io = C.includec("<stdio.h>")
  io.printf("Hello world\n")
  #io.printf("Hello world, again\n")
  #io.printf("Hello: %s\n", "world")
  #io.printf("signed: %d  unsigned: %u\n", 10, -1)