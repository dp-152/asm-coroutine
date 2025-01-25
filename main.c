#include <stdio.h>

void corout_init();
void corout_go(void (*f)());
void corout_yield();

int corout_count = 0;
int curr_corout = 0;

void print_corout()
{
  curr_corout++;
  if (curr_corout > corout_count) {
    curr_corout = 1;
  }
  printf("At coroutine %d\n", curr_corout);
}

void counter()
{
  for (int i = 0; i < 10; ++i) 
  {
    print_corout();
    printf("Counter: %d\n", i);
    corout_yield();
  }
}

int main() {
  int max_corout = 9;
  corout_init();
  while (max_corout--) {
    corout_count++;
    corout_go(counter);
  }
  while(1) {
    printf("At main\n");
    corout_yield();
  }
  return 0;
}
