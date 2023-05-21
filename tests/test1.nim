type proc_A_7995805007748477543 = proc (a: int; b: int): int {.cdecl.}

template tmpl_A_7995805007748477543*(a: int; b: int): untyped = cast[proc_A_7995805007748477543](123)(a, b)

const
  var_A_7995805007748477543 = cast[proc_A_7995805007748477543](123)

proc A(a: int; b: int): int {.gcsafe, inline.} =
  tmpl_A_7995805007748477543(a, b)

var
  a = 0
  b = 1

echo A(a, b)
echo tmpl_A_7995805007748477543(a, b)
