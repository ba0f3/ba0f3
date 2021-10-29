import os, ba0f3/logger

initLogger()

debug "this is a debug message"
info "this is an info message"

setLogLevel(lvlInfo)
debug "this debug message wont shown"
info "this is another info message"

setLogLevel(lvlDebug)

debug "this debug message will shown"