#include <stdio.h>
#include "corout.h"

void counter(void *arg)
{
  long int n = (long int)arg;
  printf("[%zu]: started, counting up to %ld\n", corout_id(), n);
  for (long int i = 0; i < n; i++)
  {
    printf("[%zu]: %ld\n", corout_id(), i);
    yield;
  }
  printf("[%zu]: done\n", corout_id());
}

int main()
{
  corout_init();

  corout_go(&counter, (void *)5);
  corout_go(&counter, (void *)10);
  while (corout_active() > 1)
  {
    yield;
  }

  corout_go(&counter, (void *)15);
  corout_go(&counter, (void *)12);
  while (corout_active() > 2)
  {
    yield;
  }

  corout_go(&counter, (void *)20);
  while (corout_active())
  {
    yield;
  }

  printf("Done\n");
  return 0;
}
