
gcc -m32 -c -o main.o main.c
ld main.o -Ttext 0xc0001500 -e main -o kernel.bin
if [[ "$?" -eq "0" ]]; then
	echo "build kernel.bin success!"
else
	echo "compile kernel.bin error"
	exit
fi

dd if=kernel.bin of==/home/tangle/work/bochs/bin/hd60M.img bs=512 count=200 seek=9 conv=notrunc
