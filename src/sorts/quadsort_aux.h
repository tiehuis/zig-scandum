// quadsort 1.2.1.2 - Igor van den Hoven ivdhoven@gmail.com

#ifndef QUADSORT_AUX_H
#define QUADSORT_AUX_H

#include <stdlib.h>

//////////////////////////////////////////////////////////
//┌────────────────────────────────────────────────────┐//
//│                █████┐    ██████┐ ██████┐████████┐  │//
//│               ██┌──██┐   ██┌──██┐└─██┌─┘└──██┌──┘  │//
//│               └█████┌┘   ██████┌┘  ██│     ██│     │//
//│               ██┌──██┐   ██┌──██┐  ██│     ██│     │//
//│               └█████┌┘   ██████┌┘██████┐   ██│     │//
//│                └────┘    └─────┘ └─────┘   └─┘     │//
//└────────────────────────────────────────────────────┘//
//////////////////////////////////////////////////////////

#define VAR char
#define FUNC(NAME) NAME##8

void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);

#undef VAR
#undef FUNC

//////////////////////////////////////////////////////////
//┌────────────────────────────────────────────────────┐//
//│           ▄██┐   █████┐    ██████┐ ██████┐████████┐│//
//│          ████│  ██┌───┘    ██┌──██┐└─██┌─┘└──██┌──┘│//
//│          └─██│  ██████┐    ██████┌┘  ██│     ██│   │//
//│            ██│  ██┌──██┐   ██┌──██┐  ██│     ██│   │//
//│          ██████┐└█████┌┘   ██████┌┘██████┐   ██│   │//
//│          └─────┘ └────┘    └─────┘ └─────┘   └─┘   │//
//└────────────────────────────────────────────────────┘//
//////////////////////////////////////////////////////////

#define VAR short
#define FUNC(NAME) NAME##16

void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);

#undef VAR
#undef FUNC

//////////////////////////////////////////////////////////
// ┌───────────────────────────────────────────────────┐//
// │       ██████┐ ██████┐    ██████┐ ██████┐████████┐ │//
// │       └────██┐└────██┐   ██┌──██┐└─██┌─┘└──██┌──┘ │//
// │        █████┌┘ █████┌┘   ██████┌┘  ██│     ██│    │//
// │        └───██┐██┌───┘    ██┌──██┐  ██│     ██│    │//
// │       ██████┌┘███████┐   ██████┌┘██████┐   ██│    │//
// │       └─────┘ └──────┘   └─────┘ └─────┘   └─┘    │//
// └───────────────────────────────────────────────────┘//
//////////////////////////////////////////////////////////

#define VAR int
#define FUNC(NAME) NAME##32

void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);

#undef VAR
#undef FUNC

#define VAR int
#define FUNC(NAME) NAME##_int32
#ifndef cmp
  #define cmp(a,b) (*(a) > *(b))
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
  void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
  void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
  void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);
  #undef cmp
#else
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
  void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
  void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
  void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);
#endif
#undef VAR
#undef FUNC

#define VAR unsigned int
#define FUNC(NAME) NAME##_uint32
#ifndef cmp
  #define cmp(a,b) (*(a) > *(b))
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
  void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
  void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
  void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);
  #undef cmp
#else
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
  void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
  void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
  void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);
#endif
#undef VAR
#undef FUNC

//////////////////////////////////////////////////////////
// ┌───────────────────────────────────────────────────┐//
// │        █████┐ ██┐  ██┐   ██████┐ ██████┐████████┐ │//
// │       ██┌───┘ ██│  ██│   ██┌──██┐└─██┌─┘└──██┌──┘ │//
// │       ██████┐ ███████│   ██████┌┘  ██│     ██│    │//
// │       ██┌──██┐└────██│   ██┌──██┐  ██│     ██│    │//
// │       └█████┌┘     ██│   ██████┌┘██████┐   ██│    │//
// │        └────┘      └─┘   └─────┘ └─────┘   └─┘    │//
// └───────────────────────────────────────────────────┘//
//////////////////////////////////////////////////////////

#define VAR long long
#define FUNC(NAME) NAME##64

void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);

#undef VAR
#undef FUNC

#undef VAR
#undef FUNC

#define VAR long long
#define FUNC(NAME) NAME##_int64
#ifndef cmp
  #define cmp(a,b) (*(a) > *(b))
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
  void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
  void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
  void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);
  #undef cmp
#else
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
  void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
  void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
  void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);
#endif
#undef VAR
#undef FUNC

#define VAR unsigned long long
#define FUNC(NAME) NAME##_uint64
#ifndef cmp
  #define cmp(a,b) (*(a) > *(b))
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
  void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
  void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
  void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);
  #undef cmp
#else
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
  void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
  void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
  void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);
#endif
#undef VAR
#undef FUNC

//////////////////////////////////////////////////////////
//┌────────────────────────────────────────────────────┐//
//│  ▄██┐  ██████┐  █████┐    ██████┐ ██████┐████████┐ │//
//│ ████│  └────██┐██┌──██┐   ██┌──██┐└─██┌─┘└──██┌──┘ │//
//│ └─██│   █████┌┘└█████┌┘   ██████┌┘  ██│     ██│    │//
//│   ██│  ██┌───┘ ██┌──██┐   ██┌──██┐  ██│     ██│    │//
//│ ██████┐███████┐└█████┌┘   ██████┌┘██████┐   ██│    │//
//│ └─────┘└──────┘ └────┘    └─────┘ └─────┘   └─┘    │//
//└────────────────────────────────────────────────────┘//
//////////////////////////////////////////////////////////

// 128 reflects the name, though the actual size of a long double is 64, 80,
// 96, or 128 bits, depending on platform.

#if (DBL_MANT_DIG < LDBL_MANT_DIG)
  #define VAR long double
  #define FUNC(NAME) NAME##128
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
  void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
  void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
  void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
  void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
  void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);
  #undef VAR
  #undef FUNC
#endif

///////////////////////////////////////////////////////////
//┌─────────────────────────────────────────────────────┐//
//│ ██████┐██┐   ██┐███████┐████████┐ ██████┐ ███┐  ███┐│//
//│██┌────┘██│   ██│██┌────┘└──██┌──┘██┌───██┐████┐████││//
//│██│     ██│   ██│███████┐   ██│   ██│   ██│██┌███┌██││//
//│██│     ██│   ██│└────██│   ██│   ██│   ██│██│└█┌┘██││//
//│└██████┐└██████┌┘███████│   ██│   └██████┌┘██│ └┘ ██││//
//│ └─────┘ └─────┘ └──────┘   └─┘    └─────┘ └─┘    └─┘│//
//└─────────────────────────────────────────────────────┘//
///////////////////////////////////////////////////////////

/*
typedef struct {char bytes[32];} struct256;
#define VAR struct256
#define FUNC(NAME) NAME##256

void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(quad_reversal)(VAR *pta, VAR *ptz);
void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp);
void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp);
void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left);
void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp);
void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp);

#undef VAR
#undef FUNC
*/

#endif