
nasm -I./ -o loader.bin loader.S
if [[ "$?" -eq "0" ]]; then
	dd if=loader.bin of=/home/tangle/work/bochs/bin/hd60M.img bs=512 count=4 seek=2 conv=notrunc
else
	echo "compile loader.bin error"
	exit
fi
