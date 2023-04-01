
nasm -I./ -o mbr.bin mbr.S
if [[ "$?" -eq "0" ]]; then
	dd if=mbr.bin of=/home/tangle/work/bochs/bin/hd60M.img bs=512 count=1 conv=notrunc
else
	echo "compiler error"
	exit
fi

