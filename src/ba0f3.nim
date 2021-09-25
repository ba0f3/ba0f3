import macros, os

macro includeAll(): untyped =
  result = newNimNode(nnkStmtList)
  let dir = currentSourcePath.splitPath.head / "ba0f3"
  for (kind, path) in dir.walkDir():
    if kind == pcFile:
      result.add newTree(nnkIncludeStmt, newIdentNode(path))


includeAll()