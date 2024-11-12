/*
	Copyright (C) 2014-2022 Igor van den Hoven ivdhoven@gmail.com
*/

/*
	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/*
	piposort 1.1.5.4
*/

#define TRACE_PREFIX "pipo"
#include "trace.h"

void FUNC(branchless_oddeven_sort)(VAR *array, size_t nmemb, CMPFUNC *cmp)
{
	size_t n = nmemb;
	O("branchless_oddeven_sort: n=%d\n", n);
	VAR swap, *pta, *pte;
	unsigned char w = 1, x, y, z = 1;

	switch (nmemb)
	{
		default:
			pte = array + nmemb - 3;
			do
			{
				pta = pte + (z = !z);

				do
				{
					x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap; pta -= 2; w |= x;
				}
				while (pta >= array);
			}
			while (w-- && --nmemb);
			break;
		case 3:
			pta = array;
			x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap; pta++;
			x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap;
			if (x == 0)
				break;
		case 2:
			pta = array;
			x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap;
		case 1:
		case 0:
			break;
	}
}

void FUNC(oddeven_parity_merge)(VAR *from, VAR *dest, size_t left, size_t right, CMPFUNC *cmp)
{
	O("oddeven_parity_merge: l=%zu, r=%zu\n", left, right);
	VAR *ptl, *ptr, *tpl, *tpr, *tpd, *ptd;
	unsigned char x;

	ptl = from; ptr = from + left; ptd = dest;
	tpl = from + left - 1; tpr = from + left + right - 1; tpd = dest + left + right - 1;

	if (left < right)
	{
		O("oddeven_parity_merge: l<r l=%zu, r=%zu\n", *ptl, *ptr);
		*ptd++ = cmp(ptl, ptr) <= 0 ? *ptl++ : *ptr++;
        O("oddeven_parity_merge: l<r end d=%zu, l=%zu, r=%zu\n", ptd - dest, ptl - from, ptr - from);
	}

	O_A("array", ptl, ptr - ptl + 1);
	while (--left)
	{
		O("oddeven_parity_merge:cmp1 l=%zu, r=%zu\n", *ptl, *ptr);
		x = cmp(ptl, ptr) <= 0;
		O("oddeven_parity_merge: x=%d, l=%zu, r=%zu\n", x, ptl - from, ptr - from);
		*ptd = *ptl; ptl += x; ptd[x] = *ptr; ptr += !x; ptd++;

		O("oddeven_parity_merge:cmp2 l=%zu, r=%zu\n", *tpl, *tpr);
		x = cmp(tpl, tpr) <= 0;
		O("oddeven_parity_merge: y=%d, l=%zu, r=%zu\n", x, tpl - from, tpr - from);
		*tpd = *tpl; tpl -= !x; tpd--; tpd[x] = *tpr; tpr -= x;
	}
	*tpd = cmp(tpl, tpr)  > 0 ? *tpl : *tpr;
	*ptd = cmp(ptl, ptr) <= 0 ? *ptl : *ptr;
}

void FUNC(auxiliary_rotation)(VAR *array, VAR *swap, size_t left, size_t right)
{
	O("auxiliary_rotation: l=%zu, r=%zu\n", left, right);
	memcpy(swap, array, left * sizeof(VAR));

	memmove(array, array + left, right * sizeof(VAR));

	memcpy(array + right, swap, left * sizeof(VAR));
}

void FUNC(ping_pong_merge)(VAR *array, VAR *swap, size_t nmemb, CMPFUNC *cmp)
{
	O("ping_pong_merge: n=%zu\n", nmemb);
	size_t quad1, quad2, quad3, quad4, half1, half2;

	if (nmemb <= 7)
	{
		O("ping_pong_merge: n < 7\n");
		FUNC(branchless_oddeven_sort)(array, nmemb, cmp);
		return;
	}
	half1 = nmemb / 2;
	quad1 = half1 / 2;
	quad2 = half1 - quad1;
	half2 = nmemb - half1;
	quad3 = half2 / 2;
	quad4 = half2 - quad3;

	FUNC(ping_pong_merge)(array, swap, quad1, cmp);
	FUNC(ping_pong_merge)(array + quad1, swap, quad2, cmp);
	FUNC(ping_pong_merge)(array + half1, swap, quad3, cmp);
	FUNC(ping_pong_merge)(array + half1 + quad3, swap, quad4, cmp);

	O("ping_pong_merge: branch 1 check: c0,0=%zu c0,1=%zu c1,0=%zu c1,1=%zu c2,0=%zu c2,1=%zu\n",
		array[quad1 - 1], array[quad1],
		array[half1 - 1], array[half1],
		array[half1 + quad3 - 1], array[half1 + quad3]
	);
	if (cmp(array + quad1 - 1, array + quad1) <= 0 && cmp(array + half1 - 1, array + half1) <= 0 && cmp(array + half1 + quad3 - 1, array + half1 + quad3) <= 0)
	{
		O("ping_pong_merge: branch 1\n");
		return;
	}

	O("ping_pong_merge: branch 2 check: c0,0=%zu c0,1=%zu c1,0=%zu c1,1=%zu c2,0=%zu c2,1=%zu\n",
		array[0], array[half1 - 1],
		array[quad1], array[half1 + quad3 - 1],
		array[half1], array[nmemb - 1]
	);
	if (cmp(array, array + half1 - 1) > 0 && cmp(array + quad1, array + half1 + quad3 - 1) > 0 && cmp(array + half1, array + nmemb - 1) > 0)
	{
		O("ping_pong_merge: branch 2\n");
		FUNC(auxiliary_rotation)(array, swap, quad1, quad2 + half2);
		FUNC(auxiliary_rotation)(array, swap, quad2, half2);
		FUNC(auxiliary_rotation)(array, swap, quad3, quad4);
		return;
	}

	FUNC(oddeven_parity_merge)(array, swap, quad1, quad2, cmp);
	FUNC(oddeven_parity_merge)(array + half1, swap + half1, quad3, quad4, cmp);
	FUNC(oddeven_parity_merge)(swap, array, half1, half2, cmp);
}

void FUNC(piposort)(VAR *array, size_t nmemb, CMPFUNC *cmp)
{
	O("piposort: n=%zu\n", nmemb);
	VAR *swap = malloc(nmemb * sizeof(VAR));

	FUNC(ping_pong_merge)(array, swap, nmemb, cmp);

	free(swap);
}