import os, strutils, mummy, mummy/routers, waterpark/sqlite, json
import ba0f3/sqlfmt

let db = newSqlitePool(10, getAppDir() & "/example.sqlite3")


proc getHandler(request: Request) =
  var
    id: int
    headers: HttpHeaders

  headers["Content-Type"] = "text/plain"
  try:
    id = parseInt(request.queryParams["id"])
  except:
    request.respond(400, headers, "Bad Request")
    return


  var row: seq[string]
  db.withConnection conn:
     row = conn.getRow(sqlfmt("SELECT * FROM users WHERE id=%d", id))

  if row[0].len > 0:
    request.respond(200, headers, $row)
  else:
    request.respond(404, headers, "User not found")


proc searchHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/plain"

  var username = request.queryParams["username"]
  db.withConnection conn:
    let row = conn.getAllRows(sqlfmt("SELECT * FROM users WHERE username LIKE '%%%S%%'", username))
    if row.len > 0:
      request.respond(200, headers, $row)
    else:
      request.respond(200, headers, "not found")

proc loginHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/plain"

  if request.body.len == 0:
    request.respond(400, headers, "Bad Request")
    return

  var obj: JsonNode
  try:
    obj = parseJson(request.body)
  except:
    request.respond(400, headers, "Bad Request")
    return
  var
    count: int = 0
    username = obj["username"].getStr()
    password = obj["password"].getStr()

  db.withConnection conn:
    count = parseInt(conn.getValue(sqlfmt("SELECT COUNT(id) FROM users WHERE username=%s AND password=%s LIMIT 1", username, password)))

  if count > 0:
    request.respond(200, headers, "Login success")
  else:
    request.respond(401, headers, "Unauthorized")

var router: Router
router.get("/get", getHandler)
router.get("/search", searchHandler)
router.post("/login", loginHandler)

let server = newServer(router)
echo "Serving on http://localhost:8080"
server.serve(Port(8080))