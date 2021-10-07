import os, ba0f3/[logger, luascripting]


const PATH = currentSourcePath().splitPath.head
var L = newNimLua()
let
  main = PATH / "scripts/main.lua"
  subm = PATH / "scripts/submodule.lua"

L.executeScript(main, "main")
L.executeScript(subm, "sub")
L.executeScript(main, "main")
