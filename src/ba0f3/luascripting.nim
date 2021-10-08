import tables, nimLUA, nimLUA/lua
import ./logger

initLogger()

export nimLUA

proc getScript*(L: LuaState, path: string): bool =
  var loadedScripts {.global.}: TableRef[string, int32]
  if unlikely(loadedScripts == nil):
    loadedScripts = newTable[string, int32]()

  if not loadedScripts.hasKey(path):
    var ret = L.loadfile(path)
    debug "GetScript", path, ret
    if ret != LUA_OK:
      when not defined(release):
        echo L.error()
      error "Load script error", ret
      return false

    ret = L.pcall(0, LUA_MULTRET, 0)
    if ret != LUA_OK:
      when not defined(release):
        echo L.error()
      error "Script error", ret
      return false
    L.pushvalue(-1)
    loadedScripts[path] = L.luaref(LUA_REGISTRYINDEX)
  else:
    L.rawgeti(LUA_REGISTRYINDEX, loadedScripts[path])

  return true

template executeScript*(L: LuaState, path: string, fn: string, args: varargs[untyped]) =
  debug "ExecuteScript", script=path, fun=fn
  if L.getScript(path):
    L.getglobal(fn)
    let top = L.gettop()
    if L.luatype(top) == LUA_TFUNCTION:
      callfunctionImpl("L", args)
    else:
      warn "Invalid function call", fun=fn

template executeScriptNoCache*(L: LuaState, path: string, fn: string, args: varargs[untyped]) =
  debug "ExecuteScript", script=path, fun=fn
  if L.dofile(path) == LUA_OK:
    L.getglobal(fn)
    let top = L.gettop()
    if L.luatype(top) == LUA_TFUNCTION:
      callfunctionImpl("L", args)
    else:
      warn "Invalid function call", fun=fn