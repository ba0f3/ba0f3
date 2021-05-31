import ba0f3/includec

const io = C.includec("<stdio.h>")
var
  greeting = "Hello world!\n"
  thisIsNumber = "This is a number: %d\n"
  ten = 10

io.printf(greeting)
io.printf("Hello world!\n")
io.printf("This is a number: %d\n", ten)
io.printf(thisIsNumber, 11)

io.printf("Signed decimal integer: %d\n", true)
io.printf("Unsigned decimal integer: %u and %u \n", 7235'u, -1)
io.printf("Unsigned octal: %o", 7235)
io.printf("Unsigned hexadecimal integer: %x\n", 7235)
io.printf("Unsigned hexadecimal integer (Uppercase): %X\n", 7235)
io.printf("Decimal floating point, lowercase: %f\n", 392.65'f32)
io.printf("Decimal floating point, uppercase: %F\n", 392.65)
io.printf("Scientific notation (mantissa/exponent), lowercase: %e\n", 3.9265e+2)
io.printf("Scientific notation (mantissa/exponent), uppercase: %E\n", 3.9265E+2)
io.printf("Use the shortest representation: %g\n", 392.65)
io.printf("Use the shortest representation: %G\n", 392.65)
io.printf("Hexadecimal floating point, lowercase: %a\n", 392.65)
io.printf("Hexadecimal floating point, uppercase: %A\n", 392.65)
io.printf("Character: %c\n", 'a')
io.printf("String of characters: %s\n", "sample")
io.printf("Pointer address: %p\n", addr ten)
io.printf("Nothing printed %n\n", addr ten)
io.printf("A %% followed by another %% character will write a single %% to the stream.\n")
io.exit(0)