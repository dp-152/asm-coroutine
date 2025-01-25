main: main.o corout.o
	ld -o main main.o corout.o /usr/lib/crt1.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2

main.o: main.c
	gcc -c main.c

corout.o: corout.asm
	fasm corout.asm
