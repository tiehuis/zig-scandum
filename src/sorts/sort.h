#ifndef PIPOSORT_H_H
#define PIPOSORT_H_H

#include <stdlib.h>

typedef int CMPFUNC (const void *a, const void *b);

void piposort(void *array, size_t nmemb, size_t size, CMPFUNC *cmp);
void quadsort(void *array, size_t nmemb, size_t size, CMPFUNC *cmp);
void blitsort(void *array, size_t nmemb, size_t size, CMPFUNC *cmp);
void crumsort(void *array, size_t nmemb, size_t size, CMPFUNC *cmp);
void fluxsort(void *array, size_t nmemb, size_t size, CMPFUNC *cmp);

#endif