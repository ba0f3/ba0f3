from strutils import toHex, repeat
import logger

proc hexdump*(data: pointer, length: int) =
  ## Print hex dump for a block of data
  var data = cast[cstring](data)
  var ascii: array[17, char]
  ascii[16] = '\0'
  for i in 0..15:
    stdout.write toHex(i.uint8)
    stdout.write " "
  stdout.write "| 0123456789ABCDEF\n" & "-".repeat(66) & "\n"
  for i in 0..<length:
    stdout.write toHex(data[i].uint8)
    stdout.write " "
    if data[i] >= ' ' and data[i] <= '~':
      ascii[i mod 16] = data[i]
    else:
      ascii[i mod 16] = '.'
    if (i+1) mod 16 == 0:
      echo "| ", cast[cstring](addr ascii)
    elif (i+1) == length:
      ascii[(i+1) mod 16] = '\0'
      var j = (i+1) mod 16
      while j < 16:
        stdout.write "   "
        inc(j)
      echo "| ", cast[cstring](addr ascii)

when isMainModule:
  var text = "Cong Hoa Xa Hoi Chu Nghia Viet Nam"
  hexdump(addr text[0], text.len)