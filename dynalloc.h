/**
 * Snippet from [Nob](https://github.com/tsoding/nob.h/blob/fb2b6345c1d5aa3a8ade06931a07ec796b0563f1/nob.h#L255-L270)
 * Released as public domain, courtesy of [Alexey Kutepov](https://github.com/tsoding)
 */

#ifndef DYNALLOC_INIT_CAP
#define DYNALLOC_INIT_CAP 256
#endif

#define dynalloc_append(dynalloc, item)                                                                      \
    do {                                                                                                     \
        if ((dynalloc)->count >= (dynalloc)->capacity) {                                                     \
            (dynalloc)->capacity = (dynalloc)->capacity == 0 ? DYNALLOC_INIT_CAP : (dynalloc)->capacity*2;   \
            (dynalloc)->items = realloc((dynalloc)->items, (dynalloc)->capacity*sizeof(*(dynalloc)->items)); \
            assert((dynalloc)->items != NULL && "Allocation failed!");                                       \
        }                                                                                                    \
                                                                                                             \
        (dynalloc)->items[(dynalloc)->count++] = (item);                                                     \
    } while (0)
