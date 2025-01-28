#ifndef COROUT_H_
#define COROUT_H_

void corout_init();
void corout_yield();
void corout_go(void (*f)(void*), void *arg);
size_t corout_id();
size_t corout_active();

#endif

#ifndef yield
#define yield corout_yield();
#endif
