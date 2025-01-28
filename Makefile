main: main.o corout.o
	gcc -Wall -Wextra -ggdb -masm=intel -o main main.c corout.o

corout.o: corout.c
	gcc -Wall -Wextra -ggdb -masm=intel -c corout.c
