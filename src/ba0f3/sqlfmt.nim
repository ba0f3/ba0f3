import macros, db_connector/db_common

proc sqlQuote*(s: string, addQuotes = true): string =
  ## DB quotes the string. Note that this doesn't escape `%` and `_`.
  result = newStringOfCap(s.len + 2)
  if addQuotes:
    result.add("'")
  for c in items(s):
    # see https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html#mysql-escaping
    case c
    of '\0': result.add "\\0"
    of '\b': result.add "\\b"
    of '\t': result.add "\\t"
    of '\l': result.add "\\n"
    of '\r': result.add "\\r"
    of '\x1a': result.add "\\Z"
    of '"': result.add "\\\""
    of '\'': result.add "\\'"
    of '\\': result.add "\\\\"
    else: result.add c
  if addQuotes:
    result.add("'")

proc sqlJoin*(args: varargs[string]): string =
  for arg in args:
    result = result & arg

macro fmtImpl(query: static[string], args: varargs[untyped]): untyped =
  result = newNimNode(nnkCall)
  result.add(newIdentNode("sql"))

  var joinNode = newCall("sqlJoin")
  result.add(joinNode)

  var
    c: char
    pos = 0
    s = ""
    i = 0
  while i < query.len:
    c = query[i]
    if c == '%':
      if query[i+1] == '%':
        s.add(c)
        inc(i, 2)
        continue

      if pos == args.len:
        echo pos, " ", args.len
        raise newException(ValueError, "The number of '%' given exceeds the number of parameters present in the query.")

      if s.len > 0:
        joinNode.add(newStrLitNode(s))
        s.setLen(0)

      echo pos, " ", args[pos].kind


      case query[i+1]:
      of 's':
        if args[pos].kind == nnkIdent:
          joinNode.add(newCall("sqlQuote", args[pos]))
        else:
          joinNode.add(newStrLitNode(sqlQuote($args[pos])))
      of 'S':
        if args[pos].kind == nnkIdent:
          joinNode.add(newCall("sqlQuote", args[pos], newLit(false)))
        else:
          joinNode.add(newStrLitNode(sqlQuote($args[pos], false)))
      of 'd':
        if args[pos].kind == nnkIdent:
          joinNode.add(prefix(args[pos], "$"))
        else:
          joinNode.add(toStrLit(args[pos]))
      else:
        raise newException(ValueError, "Unsupported format character %" & query[i+1])
      inc(i)
      inc(pos)
    else:
      s.add(c)
    inc(i)
  #echo treeRepr(result)

template sqlfmt*(query: string, args: varargs[untyped]): untyped =
  fmtImpl(query, args)

when isMainModule:
  let
    name = "john's"
    age = 25


  echo string(sqlfmt("SELECT * FROM User WHERE username = %s AND class = %s AND age = %d LIMIT %d", name, "nim'", age, 1))
  echo string(sqlfmt("SELECT * FROM User WHERE username LIKE '%%%S%%' LIMIT %d", name, 10))