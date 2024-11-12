#ifdef TRACE
#define O(...) fprintf(stderr, "|" TRACE_PREFIX "| " __VA_ARGS__)
#define O_RAW(...) fprintf(stderr, __VA_ARGS__)
#define O_A(p, a, l) do {            \
    fprintf(stderr, "|" TRACE_PREFIX "| %s: { ", p);       \
    for (size_t i = 0; i < l - 1; i++) { \
        fprintf(stderr, "%zu, ", a[i]);         \
    }                                \
    fprintf(stderr, "%zu }\n", a[l - 1]);       \
} while (0)
#else
#define O
#define O_RAW
#define O_A
#endif