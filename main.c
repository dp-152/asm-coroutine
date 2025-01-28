#include <stdio.h>
#include "corout.h"

void counter()
{
  for (int i = 0; i < 10; ++i) 
  {
    printf("At coroutine %d\n", corout_id());
    printf("Counter: %d\n", i);
    corout_yield();
  }
}

int main() {
  int max_corout = 9;
  corout_init();
  while (max_corout--) {
    corout_go(&counter, 0);
  }
  while(corout_active()) {
    printf("At main\n");
    corout_yield();
  }
  return 0;
}
