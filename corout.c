#include <assert.h>
#include <stdlib.h>
#include "dynalloc.h"

/**
 * Stack size of each coroutine is 4kb (4*1024)
 */
#define COROUT_STACK_LEN (4 * 1024)

typedef struct Context
{
  long int id;
  char active;
  void *rsp;
  void *left;
  void *right;
} Context;

typedef struct Scheduler
{
  Context *items;
  size_t count;
  size_t capacity;
  size_t current;
  size_t active;
  long int last_id;
} Scheduler;

Scheduler scheduler = {};

/**
 * Restores the execution context of the next coroutine
 * This is done by `pop`ing the register values in stack of the new coroutine
 * in the opposite order as they were `push`ed in `corout_yield()`
 *
 * @param rsp Stack pointer address of the next coroutine
 */
void __attribute__((naked)) __restore(void *rsp)
{
  (void)rsp;
  asm(
      "mov rsp, rdi\n\t"
      "pop r15\n\t"
      "pop r14\n\t"
      "pop r13\n\t"
      "pop r12\n\t"
      "pop rbx\n\t"
      "pop rbp\n\t"
      "pop rdi\n\t"
      "ret\n" // The last value in the stack is the instruction pointer
  );
}

/**
 * Switches to the next coroutine in the scheduler
 *
 * @param rsp Stack pointer address of the current coroutine
 */
void __next(void *rsp)
{
  Context *current = &scheduler.items[scheduler.current];
  // Save the `rsp` of the current coroutine
  current->rsp = rsp;

  Context *next;
  do
  {
    // Switch to the next active routine, wrapping to the first if needed
    scheduler.current = (scheduler.current + 1) % scheduler.count;
    next = &scheduler.items[scheduler.current];
  } while (!next->active);

  __restore(next->rsp);
}

/**
 * Return point for finished coroutines.
 * Marks the current context as inactive, decrements the count of active contexts in the scheduler,
 * and restores the next active context in the scheduler.
 * This function never deallocates memory allocated for a coroutine stack.
 */
void __ret()
{
  Context *current = &scheduler.items[scheduler.current];
  current->active = 0;
  scheduler.active -= 1;

  // If current coroutine is main (ID 0), resume execution
  if (current->id == 0)
  {
    scheduler.active = 0;
    __restore(current->rsp);
  }

  // scheduler.items[scheduler.current] = scheduler.items[scheduler.count - 1];
  // scheduler.items[scheduler.count - 1] = current;
  Context *next = &scheduler.items[scheduler.current];
  while (!next->active)
  {
    scheduler.current = (scheduler.current + 1) % scheduler.count;
    next = &scheduler.items[scheduler.current];
  }
  // scheduler.current %= scheduler.count;

  __restore(next->rsp);
}

/**
 * Initializes the coroutine environment.
 * This must be called before starting any coroutines using `corout_go()`.
 */
void corout_init()
{
  if (scheduler.count > 0) return;

  scheduler.active += 1;
  dynalloc_append(&scheduler, ((Context){
                                  .id = scheduler.last_id++,
                                  .active = 1,
                                  .left = 0,
                                  .right = 0,
                                  .rsp = 0,
                              }));
}

/**
 * Signals the current coroutine is done working for now, and delegates to the next coroutine in the scheduler
 * Saves the current state of the registers in the stack itself, then `jmp`s to `__next()`
 * Saved registers are the same as in musl's `longjmp`, https://git.musl-libc.org/cgit/musl/tree/src/setjmp/x86_64/longjmp.s?h=v1.2.5
 */
void __attribute__((naked)) corout_yield()
{
  asm volatile(
      "push rdi\n\t"
      "push rbp\n\t"
      "push rbx\n\t"
      "push r12\n\t"
      "push r13\n\t"
      "push r14\n\t"
      "push r15\n\t"
      "mov rdi, rsp\n\t" // Moves the `rsp` of the current coroutine to the argument for `__next()`
      "jmp __next\n"     // Calls `__next()` by doing a `jmp` instead of a `call`, so that the instruction pointer is preserved
  );
}

/**
 * Initializes a new coroutine by dynamically allocating `COROUT_STACK_LEN` bytes of memory
 * and making the function `f(void*)` start execution at the rightmost end of the newly allocated space,
 * effectively making the new space the function's own, isolated call stack
 *
 * @param f Pointer to the function to be run as a coroutine. Accepts an argument `void *arg`
 * @param arg Additional argument to be passed to the coroutine function
 */
void corout_go(void (*f)(void *), void *arg)
{
  assert(scheduler.count > 0 && "Attempting to start a coroutine before calling `corout_init()`!");
  Context *context;
  char reused = 0;
  if (scheduler.active < scheduler.count) // Reuse an existing, inactive context
  {
    for (size_t i = 0; i < scheduler.count && !reused; i++)
    {
      // Set `context` pointer to scheduler item at index `i`
      context = &scheduler.items[i];
      if (!context->active)
      {
        // If `context` is not active, set reused flag and exit loop
        reused = 1;
      }
    }
  }
  else // Create a new context
  {
    // Allocate memory for the new stack, of length `COROUT_STACK_LEN` bytes
    // TODO: This memory is reused but never `free`d
    void *left = malloc(COROUT_STACK_LEN);

    // Define a pointer to the rightmost end of the newly allocated memory
    // This will serve as the `%rsp` for the new coroutine
    void **right = (void **)((char *)left + COROUT_STACK_LEN);

    // Allocate memory for the new context
    context = malloc(sizeof(Context));

    // Set left and right boundaries
    context->left = left;
    context->right = right;
  }

  // Increment active context number in scheduler
  scheduler.active += 1;

  // Set a new ID to the context
  context->id = scheduler.last_id++;

  // Set the context as active
  context->active = 1;

  // Casting as double pointer so the memory address at `rsp` can have a value assigned to it
  void **rsp = context->right;

  // "push" the address of `__ret()` into the stack.
  // This will be the address used by the `ret` instruction
  // once the stack empties and the coroutine returns.
  *(--rsp) = __ret;

  // Mimic the state of the stack required by `__restore()`
  *(--rsp) = f;   // return address is the coroutine function
  *(--rsp) = arg; // `rdi` is the argument to the coroutine function
  for (int i = 0; i < 6; i++)
  {
    *(--rsp) = 0; // `rbx`, `rbp`, `r12`, `r13`, `r14` and `r15` all initialize to 0;
  }

  // Set the `rsp` value of the context to the local `rsp` value;
  context->rsp = rsp;
  if (!reused)
  {
    // Append the new context to the scheduler
    dynalloc_append(&scheduler, *context);

    // Since `context` is passed as a value, free the local allocation
    free(context);
  }
}

/**
 * Returns the ID of the current coroutine.
 */
size_t corout_id()
{
  return scheduler.items[scheduler.current].id;
}

/**
 * Returns the number of active coroutines.
 * 
 * Although, technically, the main execution context (where `corout_init()` was first called)
 * technically counts as one of the active coroutines, for the purposes of this call,
 * only the number of coroutines started with `coroutine_go()` is returned.
 */
size_t corout_active()
{
  return scheduler.active - 1;
}
