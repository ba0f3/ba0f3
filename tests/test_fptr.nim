import ba0f3/fptr, fptr/[one, two]

echo one.add(1, 2)
var a1 = faddr one.add
var a2 = faddr two.add
echo a1[](2, 3)
echo a2[](2, 3)
