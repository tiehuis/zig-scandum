// quadsort 1.2.1.2 - Igor van den Hoven ivdhoven@gmail.com

#define TRACE_PREFIX "quad"
#include "trace.h"

// the next seven functions are used for sorting 0 to 31 elements

void FUNC(tiny_sort)(VAR *array, size_t nmemb, CMPFUNC *cmp)
{
    O("tiny_sort: n=%zu\n", nmemb);
	VAR swap, *pta;
	size_t x, y;

	switch (nmemb)
	{
		case 4:
			pta = array;
			x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap; pta += 2;
			x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap; pta--;

			if (cmp(pta, pta + 1) > 0)
			{
				swap = pta[0]; pta[0] = pta[1]; pta[1] = swap; pta--;

				x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap; pta += 2;
				x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap; pta--;
				x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap;
			}
			return;
		case 3:
			pta = array;
			x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap; pta++;
			x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap;
		case 2:
			pta = array;
			x = cmp(pta, pta + 1) > 0; y = !x; swap = pta[y]; pta[0] = pta[x]; pta[1] = swap;
		case 1:
		case 0:
			return;
	}
}

// This function requires a minimum offset of 2 to work properly

void FUNC(twice_unguarded_insert)(VAR *array, size_t offset, size_t nmemb, CMPFUNC *cmp)
{
    O("twice_unguarded_insert: o=%zu, n=%zu\n", offset, nmemb);
	VAR key, *pta, *end;
	size_t i, top, x, y;

	for (i = offset ; i < nmemb ; i++)
	{
		pta = end = array + i;

		if (cmp(--pta, end) <= 0)
		{
			continue;
		}

		key = *end;
		//O("twice_unguarded_insert: k=%zu\n", key);

		if (cmp(array + 1, &key) > 0)
		{
			//O("twice_unguarded_insert: branch 1\n");
			top = i - 1;

			do
			{
				*end-- = *pta--;
			}
			while (--top);

			*end-- = key;
		}
		else
		{
			//O("twice_unguarded_insert: branch 2\n");
			do
			{
				*end-- = *pta--;
				*end-- = *pta--;
			}
			while (cmp(pta, &key) > 0);

			end[0] = end[1];
			end[1] = key;
		}
		x = cmp(end, end + 1) > 0; y = !x; key = end[y]; end[0] = end[x]; end[1] = key;
	}
}

void FUNC(quad_swap_four)(VAR *array, CMPFUNC *cmp)
{
    O("quad_swap_four\n");
	VAR *pta, swap;
	size_t x, y;

	pta = array;

	swap_branchless(pta, swap, x, y, cmp); pta += 2;
	swap_branchless(pta, swap, x, y, cmp); pta--;

	if (cmp(pta, pta + 1) > 0)
	{
        O("quad_swap_four: branch 1\n");
		swap = pta[0]; pta[0] = pta[1]; pta[1] = swap; pta--;

		swap_branchless(pta, swap, x, y, cmp); pta += 2;
		swap_branchless(pta, swap, x, y, cmp); pta--;
		swap_branchless(pta, swap, x, y, cmp);
	}
}

void FUNC(parity_swap_eight)(VAR *array, VAR *swap, CMPFUNC *cmp)
{
    O("parity_swap_eight\n");
	VAR tmp, *ptl, *ptr, *pts;
	size_t x, y;

	ptl = array;

	swap_branchless(ptl, tmp, x, y, cmp); ptl += 2;
	swap_branchless(ptl, tmp, x, y, cmp); ptl += 2;
	swap_branchless(ptl, tmp, x, y, cmp); ptl += 2;
	swap_branchless(ptl, tmp, x, y, cmp);

	if (cmp(array + 1, array + 2) <= 0 && cmp(array + 3, array + 4) <= 0 && cmp(array + 5, array + 6) <= 0)
	{
        O("parity_swap_eight: branch 1\n");
		return;
	}
	parity_merge_two(array + 0, swap + 0, x, y, ptl, ptr, pts, cmp);
	parity_merge_two(array + 4, swap + 4, x, y, ptl, ptr, pts, cmp);

	parity_merge_four(swap, array, x, y, ptl, ptr, pts, cmp);
}

// left must be equal or one smaller than right

void FUNC(parity_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp)
{
    O("parity_merge: l=%zu, r=%zu\n", left, right);
	VAR *ptl, *ptr, *tpl, *tpr, *tpd, *ptd;
#if !defined __clang__
	size_t x, y;
#endif
	ptl = from;
	ptr = from + left;
	ptd = dest;
	tpl = ptr - 1;
	tpr = tpl + right;
	tpd = dest + left + right - 1;

	if (left < right)
	{
        O("parity_merge: branch l < r\n");
		*ptd++ = cmp(ptl, ptr) <= 0 ? *ptl++ : *ptr++;
	}

	*ptd++ = cmp(ptl, ptr) <= 0 ? *ptl++ : *ptr++;

#if !defined cmp && !defined __clang__ // cache limit workaround for gcc
	if (left > QUAD_CACHE)
	{
		while (--left)
		{
			*ptd++ = cmp(ptl, ptr) <= 0 ? *ptl++ : *ptr++;
			*tpd-- = cmp(tpl, tpr)  > 0 ? *tpl-- : *tpr--;
		}
	}
	else
#endif
	{
		while (--left)
		{
			head_branchless_merge(ptd, x, ptl, ptr, cmp);
			tail_branchless_merge(tpd, y, tpl, tpr, cmp);
		}
	}
	*tpd = cmp(tpl, tpr)  > 0 ? *tpl : *tpr;
}


void FUNC(parity_swap_sixteen)(VAR *array, VAR *swap, CMPFUNC *cmp)
{
    O("parity_swap_sixteen\n");
	VAR *ptl, *ptr, *pts;
#if !defined __clang__
	size_t x, y;
#endif
	FUNC(quad_swap_four)(array +  0, cmp);
	FUNC(quad_swap_four)(array +  4, cmp);
	FUNC(quad_swap_four)(array +  8, cmp);
	FUNC(quad_swap_four)(array + 12, cmp);

	if (cmp(array + 3, array + 4) <= 0 && cmp(array + 7, array + 8) <= 0 && cmp(array + 11, array + 12) <= 0)
	{
        O("parity_swap_sixteen: branch 1\n");
		return;
	}
	parity_merge_four(array + 0, swap + 0, x, y, ptl, ptr, pts, cmp);
	parity_merge_four(array + 8, swap + 8, x, y, ptl, ptr, pts, cmp);

	FUNC(parity_merge)(array, swap, 8, 8, cmp);
}

void FUNC(tail_swap)(VAR *array, VAR *swap, size_t nmemb, CMPFUNC *cmp)
{
    O("tail_swap: n=%zu\n", nmemb);
	if (nmemb < 5)
	{
		FUNC(tiny_sort)(array, nmemb, cmp);
		return;
	}
	if (nmemb < 8)
	{
		FUNC(quad_swap_four)(array, cmp);
		FUNC(twice_unguarded_insert)(array, 4, nmemb, cmp);
		return;
	}
	if (nmemb < 12)
	{
		FUNC(parity_swap_eight)(array, swap, cmp);
		FUNC(twice_unguarded_insert)(array, 8, nmemb, cmp);
		return;
	}
	if (nmemb >= 16 && nmemb < 24)
	{
		FUNC(parity_swap_sixteen)(array, swap, cmp);
		FUNC(twice_unguarded_insert)(array, 16, nmemb, cmp);
		return;
	}

	size_t quad1, quad2, quad3, quad4, half1, half2;

	half1 = nmemb / 2;
	quad1 = half1 / 2;
	quad2 = half1 - quad1;

	half2 = nmemb - half1;
	quad3 = half2 / 2;
	quad4 = half2 - quad3;

	VAR *pta = array;

	FUNC(tail_swap)(pta, swap, quad1, cmp); pta += quad1;
	FUNC(tail_swap)(pta, swap, quad2, cmp); pta += quad2;
	FUNC(tail_swap)(pta, swap, quad3, cmp); pta += quad3;
	FUNC(tail_swap)(pta, swap, quad4, cmp);

	if (cmp(array + quad1 - 1, array + quad1) <= 0 && cmp(array + half1 - 1, array + half1) <= 0 && cmp(pta - 1, pta) <= 0)
	{
        O("tail_swap: branch 1\n");
		return;
	}

	FUNC(parity_merge)(swap, array, quad1, quad2, cmp);
	FUNC(parity_merge)(swap + half1, array + half1, quad3, quad4, cmp);
	FUNC(parity_merge)(array, swap, half1, half2, cmp);
}

// the next three functions create sorted blocks of 32 elements

void FUNC(quad_reversal)(VAR *base, VAR *pta, VAR *ptz)
{
	VAR *ptb, *pty, tmp1, tmp2;

	size_t loop = (ptz - pta) / 2;

	ptb = pta + loop;
	pty = ptz - loop;
	O("quad_reversal: loop=%zu, pta=%zu, ptz=%zu\n", loop, pta - base, ptz - base);

	if (loop % 2 == 0)
	{
        O("quad_reversal: branch 1\n");
		tmp2 = *ptb; *ptb-- = *pty; *pty++ = tmp2; loop--;
	}

	loop /= 2;

	do
	{
		tmp1 = *pta; *pta++ = *ptz; *ptz-- = tmp1;
		tmp2 = *ptb; *ptb-- = *pty; *pty++ = tmp2;
	}
	while (loop--);
}

void FUNC(quad_swap_merge)(VAR *array, VAR *swap, CMPFUNC *cmp)
{
    O("quad_swap_merge\n");
	VAR *pts, *ptl, *ptr;
#if !defined __clang__
	size_t x, y;
#endif
	parity_merge_two(array + 0, swap + 0, x, y, ptl, ptr, pts, cmp);
	parity_merge_two(array + 4, swap + 4, x, y, ptl, ptr, pts, cmp);

	parity_merge_four(swap, array, x, y, ptl, ptr, pts, cmp);
}

void FUNC(tail_merge)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t block, CMPFUNC *cmp);

size_t FUNC(quad_swap)(VAR *array, size_t nmemb, CMPFUNC *cmp)
{
    O("quad_swap: n=%zu\n", nmemb);
	VAR tmp, swap[32];
	size_t count;
	VAR *pta, *pts;
	unsigned char v1, v2, v3, v4, x;
	pta = array;

	count = nmemb / 8;

	while (count--)
	{
		v1 = cmp(pta + 0, pta + 1) > 0;
		v2 = cmp(pta + 2, pta + 3) > 0;
		v3 = cmp(pta + 4, pta + 5) > 0;
		v4 = cmp(pta + 6, pta + 7) > 0;

		switch (v1 + v2 * 2 + v3 * 4 + v4 * 8)
		{
			case 0:
				if (cmp(pta + 1, pta + 2) <= 0 && cmp(pta + 3, pta + 4) <= 0 && cmp(pta + 5, pta + 6) <= 0)
				{
                    O("quad_swap: branch 1: goto ordered\n");
					goto ordered;
				}
				FUNC(quad_swap_merge)(pta, swap, cmp);
				break;

			case 15:
				if (cmp(pta + 1, pta + 2) > 0 && cmp(pta + 3, pta + 4) > 0 && cmp(pta + 5, pta + 6) > 0)
				{
                    O("quad_swap: branch 2: goto reversed\n");
					pts = pta;
					goto reversed;
				}

			default:
			not_ordered:
                O("quad_swap: label unordered\n");
				x = !v1; tmp = pta[x]; pta[0] = pta[v1]; pta[1] = tmp; pta += 2;
				x = !v2; tmp = pta[x]; pta[0] = pta[v2]; pta[1] = tmp; pta += 2;
				x = !v3; tmp = pta[x]; pta[0] = pta[v3]; pta[1] = tmp; pta += 2;
				x = !v4; tmp = pta[x]; pta[0] = pta[v4]; pta[1] = tmp; pta -= 6;

				FUNC(quad_swap_merge)(pta, swap, cmp);
		}
		pta += 8;

		continue;

		ordered:
		O("quad_swap: label ordered: count=%zu\n", count);

		pta += 8;

		if (count--)
		{
			if ((v1 = cmp(pta + 0, pta + 1) > 0) | (v2 = cmp(pta + 2, pta + 3) > 0) | (v3 = cmp(pta + 4, pta + 5) > 0) | (v4 = cmp(pta + 6, pta + 7) > 0))
			{
				if (v1 + v2 + v3 + v4 == 4 && cmp(pta + 1, pta + 2) > 0 && cmp(pta + 3, pta + 4) > 0 && cmp(pta + 5, pta + 6) > 0)
				{
                    O("quad_swap: branch 3: goto reversed\n");
					pts = pta;
					goto reversed;
				}
				O("quad_swap: branch 3b: goto not_ordered\n");
				goto not_ordered;
			}
			if (cmp(pta + 1, pta + 2) <= 0 && cmp(pta + 3, pta + 4) <= 0 && cmp(pta + 5, pta + 6) <= 0)
			{
				O("quad_swap: branch 4: goto ordered\n");
				goto ordered;
			}
			FUNC(quad_swap_merge)(pta, swap, cmp);
			pta += 8;
			continue;
		}
		break;

		reversed:
		O("quad_swap: label reversed\n");

		pta += 8;

		if (count--)
		{
			if ((v1 = cmp(pta + 0, pta + 1) <= 0) | (v2 = cmp(pta + 2, pta + 3) <= 0) | (v3 = cmp(pta + 4, pta + 5) <= 0) | (v4 = cmp(pta + 6, pta + 7) <= 0))
			{
				// not reversed
				O("quad_swap: branch 5: not reversed\n");
			}
			else
			{
				if (cmp(pta - 1, pta) > 0 && cmp(pta + 1, pta + 2) > 0 && cmp(pta + 3, pta + 4) > 0 && cmp(pta + 5, pta + 6) > 0)
				{
					O("quad_swap: branch 6: goto reversed\n");
					goto reversed;
				}
			}
			FUNC(quad_reversal)(array, pts, pta - 1);

			if (v1 + v2 + v3 + v4 == 4 && cmp(pta + 1, pta + 2) <= 0 && cmp(pta + 3, pta + 4) <= 0 && cmp(pta + 5, pta + 6) <= 0)
			{
				O("quad_swap: branch 7: goto ordered\n");
				goto ordered;
			}
			if (v1 + v2 + v3 + v4 == 0 && cmp(pta + 1, pta + 2)  > 0 && cmp(pta + 3, pta + 4)  > 0 && cmp(pta + 5, pta + 6)  > 0)
			{
				O("quad_swap: branch 8: goto reversed\n");
				pts = pta;
				goto reversed;
			}

			x = !v1; tmp = pta[v1]; pta[0] = pta[x]; pta[1] = tmp; pta += 2;
			x = !v2; tmp = pta[v2]; pta[0] = pta[x]; pta[1] = tmp; pta += 2;
			x = !v3; tmp = pta[v3]; pta[0] = pta[x]; pta[1] = tmp; pta += 2;
			x = !v4; tmp = pta[v4]; pta[0] = pta[x]; pta[1] = tmp; pta -= 6;

			if (cmp(pta + 1, pta + 2) > 0 || cmp(pta + 3, pta + 4) > 0 || cmp(pta + 5, pta + 6) > 0)
			{
				O("quad_swap: branch 8b: quad swap merge\n");
				FUNC(quad_swap_merge)(pta, swap, cmp);
			}
			pta += 8;
			continue;
		}

		switch (nmemb % 8)
		{
			case 7: if (cmp(pta + 5, pta + 6) <= 0) break;
			case 6: if (cmp(pta + 4, pta + 5) <= 0) break;
			case 5: if (cmp(pta + 3, pta + 4) <= 0) break;
			case 4: if (cmp(pta + 2, pta + 3) <= 0) break;
			case 3: if (cmp(pta + 1, pta + 2) <= 0) break;
			case 2: if (cmp(pta + 0, pta + 1) <= 0) break;
			case 1: if (cmp(pta - 1, pta + 0) <= 0) break;
			case 0:
				O("quad_swap: alen_mod8 = %zu\n", nmemb % 8);
				FUNC(quad_reversal)(array, pts, pta + nmemb % 8 - 1);

				if (pts == array)
				{
					return 1;
				}
				O("quad_swap: goto reverse_end\n");
				goto reverse_end;
		}
		O("quad_swap: break1\n");
		FUNC(quad_reversal)(array, pts, pta - 1);
		break;
	}
	FUNC(tail_swap)(pta, swap, nmemb % 8, cmp);

	reverse_end:
	O("quad_swap: label reverse_end\n");
	pta = array;

	for (count = nmemb / 32 ; count-- ; pta += 32)
	{
		if (cmp(pta + 7, pta + 8) <= 0 && cmp(pta + 15, pta + 16) <= 0 && cmp(pta + 23, pta + 24) <= 0)
		{
			continue;
		}
		FUNC(parity_merge)(swap, pta, 8, 8, cmp);
		FUNC(parity_merge)(swap + 16, pta + 16, 8, 8, cmp);
		FUNC(parity_merge)(pta, swap, 16, 16, cmp);
	}

	if (nmemb % 32 > 8)
	{
		FUNC(tail_merge)(pta, swap, 32, nmemb % 32, 8, cmp);
	}
	return 0;
}

// quad merge support routines

void FUNC(cross_merge)(VAR *dest, VAR *from, size_t left, size_t right, CMPFUNC *cmp)
{
    O("cross_merge: l=%zu, r=%zu\n", left, right);
	VAR *ptl, *tpl, *ptr, *tpr, *ptd, *tpd;
	size_t loop;
#if !defined __clang__
	size_t x, y;
#endif
	ptl = from;
	ptr = from + left;
	tpl = ptr - 1;
	tpr = tpl + right;

	if (left + 1 >= right && right + 1 >= left && left >= 32)
	{
		if (cmp(ptl + 15, ptr) > 0 && cmp(ptl, ptr + 15) <= 0 && cmp(tpl, tpr - 15) > 0 && cmp(tpl - 15, tpr) <= 0)
		{
			O("cross_merge: branch 1, parity merge\n");
			FUNC(parity_merge)(dest, from, left, right, cmp);
			return;
		}
	}
	ptd = dest;
	tpd = dest + left + right - 1;

	while (tpl - ptl > 8 && tpr - ptr > 8)
	{
        O("cross_merge: s; s_tpl = %zu, s_ptl = %zu, s_tpr = %zu, s_ptr = %zu\n", tpl - from, ptl - from, tpr - from, ptr - from);
		ptl8_ptr: if (cmp(ptl + 7, ptr) <= 0)
		{
			memcpy(ptd, ptl, 8 * sizeof(VAR)); ptd += 8; ptl += 8;

			if (tpl - ptl > 8) {goto ptl8_ptr;}
			//O("ptl_ptr8 break: ptd=%zu, ptl=%zu\n", ptd - dest, ptl - from);
			break;
		}
	    //O("cross_merge: skip1\n");

		ptl_ptr8: if (cmp(ptl, ptr + 7) > 0)
		{
			memcpy(ptd, ptr, 8 * sizeof(VAR)); ptd += 8; ptr += 8;

			if (tpr - ptr > 8) {goto ptl_ptr8;}
			//O("ptl_ptr8 break: ptd=%zu, ptr=%zu\n", ptd - dest, ptr - from);
			break;
		}
	    //O("cross_merge: skip2\n");

		tpl_tpr8: if (cmp(tpl, tpr - 7) <= 0)
		{
			tpd -= 7; tpr -= 7; memcpy(tpd--, tpr--, 8 * sizeof(VAR));

			if (tpr - ptr > 8) {goto tpl_tpr8;}
			//O("tpl_tpr8 break: tpd=%zu, tpr=%zu\n", tpd - dest, tpr - from);
			break;
		}
	    //O("cross_merge: skip3\n");

		tpl8_tpr: if (cmp(tpl - 7, tpr) > 0)
		{
			tpd -= 7; tpl -= 7; memcpy(tpd--, tpl--, 8 * sizeof(VAR));

			if (tpl - ptl > 8) {goto tpl8_tpr;}
			//O("tpl8_tpr break: tpd=%zu, tpl=%zu\n", tpd - dest, tpl - from);
			break;
		}
	    //O("cross_merge: skip4\n");

#if !defined cmp && !defined __clang__
		if (left > QUAD_CACHE)
		{
			loop = 8; do
			{
				*ptd++ = cmp(ptl, ptr) <= 0 ? *ptl++ : *ptr++;
				*tpd-- = cmp(tpl, tpr)  > 0 ? *tpl-- : *tpr--;
			}
			while (--loop);
		}
		else
#endif
		{
			loop = 8; do
			{
				head_branchless_merge(ptd, x, ptl, ptr, cmp);
				tail_branchless_merge(tpd, y, tpl, tpr, cmp);
			}
			while (--loop);
		}

        O("cross_merge: e; s_tpl = %zu, s_ptl = %zu, s_tpr = %zu, s_ptr = %zu\n", tpl - from, ptl - from, tpr - from, ptr - from);
	}

	if (cmp(tpl, tpr) <= 0)
	{
		while (ptl <= tpl)
		{
			*ptd++ = cmp(ptl, ptr) <= 0 ? *ptl++ : *ptr++;
		}
		while (ptr <= tpr)
		{
			*ptd++ = *ptr++;
		}
	}
	else
	{
		while (ptr <= tpr)
		{
			*ptd++ = cmp(ptl, ptr) <= 0 ? *ptl++ : *ptr++;
		}
		while (ptl <= tpl)
		{
			*ptd++ = *ptl++;
		}
	}
}

// main memory: [A][B][C][D]
// swap memory: [A  B]       step 1
// swap memory: [A  B][C  D] step 2
// main memory: [A  B  C  D] step 3

void FUNC(quad_merge_block)(VAR *array, VAR *swap, size_t block, CMPFUNC *cmp)
{
    O("quad_merge_block: block=%zu\n", block);
	VAR *pt1, *pt2, *pt3;
	size_t block_x_2 = block * 2;

	pt1 = array + block;
	pt2 = pt1 + block;
	pt3 = pt2 + block;

	switch ((cmp(pt1 - 1, pt1) <= 0) | (cmp(pt3 - 1, pt3) <= 0) * 2)
	{
		case 0:
			O("quad_merge_block: branch 1\n");
			FUNC(cross_merge)(swap, array, block, block, cmp);
			FUNC(cross_merge)(swap + block_x_2, pt2, block, block, cmp);
			break;
		case 1:
			O("quad_merge_block: branch 2\n");
			memcpy(swap, array, block_x_2 * sizeof(VAR));
			FUNC(cross_merge)(swap + block_x_2, pt2, block, block, cmp);
			break;
		case 2:
			O("quad_merge_block: branch 3\n");
			FUNC(cross_merge)(swap, array, block, block, cmp);
			memcpy(swap + block_x_2, pt2, block_x_2 * sizeof(VAR));
			break;
		case 3:
			if (cmp(pt2 - 1, pt2) <= 0) {
				return;
			}
			O("quad_merge_block: branch 4\n");
			memcpy(swap, array, block_x_2 * 2 * sizeof(VAR));
	}
	FUNC(cross_merge)(array, swap, block_x_2, block_x_2, cmp);
}

size_t FUNC(quad_merge)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t block, CMPFUNC *cmp)
{
    O("quad_merge: swap_size=%zu, n=%zu, block=%zu\n", swap_size, nmemb, block);
	VAR *pta, *pte;

	pte = array + nmemb;

	block *= 4;

	while (block <= nmemb && block <= swap_size)
	{
		pta = array;

		do
		{
			FUNC(quad_merge_block)(pta, swap, block / 4, cmp);

			pta += block;
		}
		while (pta + block <= pte);

		FUNC(tail_merge)(pta, swap, swap_size, pte - pta, block / 4, cmp);

		block *= 4;
	}

	FUNC(tail_merge)(array, swap, swap_size, nmemb, block / 4, cmp);

	return block / 2;
}

void FUNC(partial_forward_merge)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t block, CMPFUNC *cmp)
{
    O("partial_forward_merge: swap_size=%zu, n=%zu, block=%zu\n", swap_size, nmemb, block);
	VAR *ptl, *ptr, *tpl, *tpr;
	size_t x, y;

	if (nmemb == block)
	{
		return;
	}

	ptr = array + block;
	tpr = array + nmemb - 1;

	if (cmp(ptr - 1, ptr) <= 0)
	{
		return;
	}

	memcpy(swap, array, block * sizeof(VAR));

	ptl = swap;
	tpl = swap + block - 1;


	while (ptl < tpl - 1 && ptr < tpr - 1)
	{
		if (cmp(ptl, ptr + 1) > 0)
		{
			*array++ = *ptr++; *array++ = *ptr++;
		}
		else if (cmp(ptl + 1, ptr) <= 0)
		{
			*array++ = *ptl++; *array++ = *ptl++;
		}
		else
		{
			x = cmp(ptl, ptr) <= 0; y = !x; array[x] = *ptr; ptr += 1; array[y] = *ptl; ptl += 1; array += 2;
			head_branchless_merge(array, x, ptl, ptr, cmp);
		}
	}

	while (ptl <= tpl && ptr <= tpr)
	{
		*array++ = cmp(ptl, ptr) <= 0 ? *ptl++ : *ptr++;
	}

	while (ptl <= tpl)
	{
		*array++ = *ptl++;
	}
}

void FUNC(partial_backward_merge)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t block, CMPFUNC *cmp)
{
    O("partial_backward_merge: swap_size=%zu, n=%zu, block=%zu\n", swap_size, nmemb, block);
	VAR *tpl, *tpa, *tpr; // tail pointer left, array, right
	size_t right, loop, x, y;

	if (nmemb == block)
	{
		O("partial_backward_merge: branch 1\n");
		return;
	}

	tpl = array + block - 1;
	tpa = array + nmemb - 1;

	if (cmp(tpl, tpl + 1) <= 0)
	{
		O("partial_backward_merge: branch 2\n");
		return;
	}

	right = nmemb - block;

	if (nmemb <= swap_size && right >= 64)
	{
		O("partial_backward_merge: branch 3\n");
		FUNC(cross_merge)(swap, array, block, right, cmp);

		memcpy(array, swap, nmemb * sizeof(VAR));

		return;
	}

	memcpy(swap, array + block, right * sizeof(VAR));

	tpr = swap + right - 1;

	while (tpl > array + 16 && tpr > swap + 16)
	{
		tpl_tpr16: if (cmp(tpl, tpr - 15) <= 0)
		{
			loop = 16; do *tpa-- = *tpr--; while (--loop);

			if (tpr > swap + 16) {goto tpl_tpr16;} break;
		}

		tpl16_tpr: if (cmp(tpl - 15, tpr) > 0)
		{
			loop = 16; do *tpa-- = *tpl--; while (--loop);

			if (tpl > array + 16) {goto tpl16_tpr;} break;
		}

		loop = 8; do
		{
			if (cmp(tpl, tpr - 1) <= 0)
			{
				*tpa-- = *tpr--; *tpa-- = *tpr--;
			}
			else if (cmp(tpl - 1, tpr) > 0)
			{
				*tpa-- = *tpl--; *tpa-- = *tpl--;
			}
			else
			{
				x = cmp(tpl, tpr) <= 0; y = !x; tpa--; tpa[x] = *tpr; tpr -= 1; tpa[y] = *tpl; tpl -= 1; tpa--;
				tail_branchless_merge(tpa, y, tpl, tpr, cmp);
			}
		}
		while (--loop);
	}

	while (tpr > swap + 1 && tpl > array + 1)
	{
		if (cmp(tpl, tpr - 1) <= 0)
		{
			*tpa-- = *tpr--; *tpa-- = *tpr--;
		}
		else if (cmp(tpl - 1, tpr) > 0)
		{
			*tpa-- = *tpl--; *tpa-- = *tpl--;
		}
		else
		{
			x = cmp(tpl, tpr) <= 0; y = !x; tpa--; tpa[x] = *tpr; tpr -= 1; tpa[y] = *tpl; tpl -= 1; tpa--;
			tail_branchless_merge(tpa, y, tpl, tpr, cmp);
		}
	}

	while (tpr >= swap && tpl >= array)
	{
		*tpa-- = cmp(tpl, tpr) > 0 ? *tpl-- : *tpr--;
	}

	while (tpr >= swap)
	{
		*tpa-- = *tpr--;
	}
}

void FUNC(tail_merge)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t block, CMPFUNC *cmp)
{
    O("tail_merge: swap_size=%zu, n=%zu, block=%zu\n", swap_size, nmemb, block);
	VAR *pta, *pte;

	pte = array + nmemb;

	while (block < nmemb && block <= swap_size)
	{
		for (pta = array ; pta + block < pte ; pta += block * 2)
		{
			if (pta + block * 2 < pte)
			{
				FUNC(partial_backward_merge)(pta, swap, swap_size, block * 2, block, cmp);

				continue;
			}
			FUNC(partial_backward_merge)(pta, swap, swap_size, pte - pta, block, cmp);

			break;
		}
		block *= 2;
	}
}

// the next four functions provide in-place rotate merge support

void FUNC(trinity_rotation)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t left)
{
	VAR temp;
	size_t bridge, right = nmemb - left;
    O("trinity_rotation: swap_size=%zu, n=%zu, l=%zu, r=%zu\n", swap_size, nmemb, left, right);

	if (swap_size > 65536)
	{
		swap_size = 65536;
	}

	if (left < right)
	{
		if (left <= swap_size)
		{
			memcpy(swap, array, left * sizeof(VAR));
			memmove(array, array + left, right * sizeof(VAR));
			memcpy(array + right, swap, left * sizeof(VAR));
		}
		else
		{
			VAR *pta, *ptb, *ptc, *ptd;

			pta = array;
			ptb = pta + left;

			bridge = right - left;

			if (bridge <= swap_size && bridge > 3)
			{
				ptc = pta + right;
				ptd = ptc + left;

				memcpy(swap, ptb, bridge * sizeof(VAR));

				while (left--)
				{
					*--ptc = *--ptd; *ptd = *--ptb;
				}
				memcpy(pta, swap, bridge * sizeof(VAR));
			}
			else
			{
				ptc = ptb;
				ptd = ptc + right;

				bridge = left / 2;

				while (bridge--)
				{
					temp = *--ptb; *ptb = *pta; *pta++ = *ptc; *ptc++ = *--ptd; *ptd = temp;
				}

				bridge = (ptd - ptc) / 2;

				while (bridge--)
				{
					temp = *ptc; *ptc++ = *--ptd; *ptd = *pta; *pta++ = temp;
				}

				bridge = (ptd - pta) / 2;

				while (bridge--)
				{
					temp = *pta; *pta++ = *--ptd; *ptd = temp;
				}
			}
		}
	}
	else if (right < left)
	{
		if (right <= swap_size)
		{
			memcpy(swap, array + left, right * sizeof(VAR));
			memmove(array + right, array, left * sizeof(VAR));
			memcpy(array, swap, right * sizeof(VAR));
		}
		else
		{
			VAR *pta, *ptb, *ptc, *ptd;

			pta = array;
			ptb = pta + left;

			bridge = left - right;

			if (bridge <= swap_size && bridge > 3)
			{
				ptc = pta + right;
				ptd = ptc + left;

				memcpy(swap, ptc, bridge * sizeof(VAR));

				while (right--)
				{
					*ptc++ = *pta; *pta++ = *ptb++;
				}
				memcpy(ptd - bridge, swap, bridge * sizeof(VAR));
			}
			else
			{
				ptc = ptb;
				ptd = ptc + right;

				bridge = right / 2;

				while (bridge--)
				{
					temp = *--ptb; *ptb = *pta; *pta++ = *ptc; *ptc++ = *--ptd; *ptd = temp;
				}

				bridge = (ptb - pta) / 2;

				while (bridge--)
				{
					temp = *--ptb; *ptb = *pta; *pta++ = *--ptd; *ptd = temp;
				}

				bridge = (ptd - pta) / 2;

				while (bridge--)
				{
					temp = *pta; *pta++ = *--ptd; *ptd = temp;
				}
			}
		}
	}
	else
	{
		VAR *pta, *ptb;

		pta = array;
		ptb = pta + left;

		while (left--)
		{
			temp = *pta; *pta++ = *ptb; *ptb++ = temp;
		}
	}
}

size_t FUNC(monobound_binary_first)(VAR *array, VAR *value, size_t top, CMPFUNC *cmp)
{
    O("monobound_binary_first: val=%zu, top=%zu\n", *value, top);
	VAR *end;
	size_t mid;

	end = array + top;

	while (top > 1)
	{
		mid = top / 2;

		if (cmp(value, end - mid) <= 0)
		{
			end -= mid;
		}
		top -= mid;
	}

	if (cmp(value, end - 1) <= 0)
	{
		end--;
	}
	return (end - array);
}

void FUNC(rotate_merge_block)(VAR *array, VAR *swap, size_t swap_size, size_t lblock, size_t right, CMPFUNC *cmp)
{
    O("rotate_merge_block: swap_size=%zu, lblock=%zu, r=%zu\n", swap_size, lblock, right);
	size_t left, rblock, unbalanced;

	if (cmp(array + lblock - 1, array + lblock) <= 0)
	{
		return;
	}

	rblock = lblock / 2;
	lblock -= rblock;

	left = FUNC(monobound_binary_first)(array + lblock + rblock, array + lblock, right, cmp);
	O("rotate_merge_block: l=%zu, r=%zu\n", left, right);

	right -= left;

	// [ lblock ] [ rblock ] [ left ] [ right ]

	if (left)
	{
		if (lblock + left <= swap_size)
		{
			memcpy(swap, array, lblock * sizeof(VAR));
			memcpy(swap + lblock, array + lblock + rblock, left * sizeof(VAR));
			memmove(array + lblock + left, array + lblock, rblock * sizeof(VAR));

			FUNC(cross_merge)(array, swap, lblock, left, cmp);
		}
		else
		{
			FUNC(trinity_rotation)(array + lblock, swap, swap_size, rblock + left, rblock);

			unbalanced = (left * 2 < lblock) | (lblock * 2 < left);

			if (unbalanced && left <= swap_size)
			{
				FUNC(partial_backward_merge)(array, swap, swap_size, lblock + left, lblock, cmp);
			}
			else if (unbalanced && lblock <= swap_size)
			{
				FUNC(partial_forward_merge)(array, swap, swap_size, lblock + left, lblock, cmp);
			}
			else
			{
				FUNC(rotate_merge_block)(array, swap, swap_size, lblock, left, cmp);
			}
		}
	}

	if (right)
	{
		unbalanced = (right * 2 < rblock) | (rblock * 2 < right);

		if ((unbalanced && right <= swap_size) || right + rblock <= swap_size)
		{
			FUNC(partial_backward_merge)(array + lblock + left, swap, swap_size, rblock + right, rblock, cmp);
		}
		else if (unbalanced && rblock <= swap_size)
		{
			FUNC(partial_forward_merge)(array + lblock + left, swap, swap_size, rblock + right, rblock, cmp);
		}
		else
		{
			FUNC(rotate_merge_block)(array + lblock + left, swap, swap_size, rblock, right, cmp);
		}
	}
}

void FUNC(rotate_merge)(VAR *array, VAR *swap, size_t swap_size, size_t nmemb, size_t block, CMPFUNC *cmp)
{
    O("rotate_merge: swap_size=%zu, n=%zu, block=%zu\n", swap_size, nmemb, block);
	VAR *pta, *pte;

	pte = array + nmemb;

	if (nmemb <= block * 2 && nmemb - block <= swap_size)
	{
        O("rotate_merge: branch1: partial backward merge\n");
		FUNC(partial_backward_merge)(array, swap, swap_size, nmemb, block, cmp);

		return;
	}

	while (block < nmemb)
	{
		for (pta = array ; pta + block < pte ; pta += block * 2)
		{
			if (pta + block * 2 < pte)
			{
				FUNC(rotate_merge_block)(pta, swap, swap_size, block, block, cmp);

				continue;
			}
			FUNC(rotate_merge_block)(pta, swap, swap_size, block, pte - pta - block, cmp);

			break;
		}
		block *= 2;
	}
}

///////////////////////////////////////////////////////////////////////////////
//┌─────────────────────────────────────────────────────────────────────────┐//
//│    ██████┐ ██┐   ██┐ █████┐ ██████┐ ███████┐ ██████┐ ██████┐ ████████┐  │//
//│   ██┌───██┐██│   ██│██┌──██┐██┌──██┐██┌────┘██┌───██┐██┌──██┐└──██┌──┘  │//
//│   ██│   ██│██│   ██│███████│██│  ██│███████┐██│   ██│██████┌┘   ██│     │//
//│   ██│▄▄ ██│██│   ██│██┌──██│██│  ██│└────██│██│   ██│██┌──██┐   ██│     │//
//│   └██████┌┘└██████┌┘██│  ██│██████┌┘███████│└██████┌┘██│  ██│   ██│     │//
//│    └──▀▀─┘  └─────┘ └─┘  └─┘└─────┘ └──────┘ └─────┘ └─┘  └─┘   └─┘     │//
//└─────────────────────────────────────────────────────────────────────────┘//
///////////////////////////////////////////////////////////////////////////////

void FUNC(quadsort)(void *array, size_t nmemb, CMPFUNC *cmp)
{
    O("quadsort: n=%zu\n", nmemb);
	VAR *pta = (VAR *) array;

	if (nmemb < 32)
	{
		VAR swap[nmemb];

		FUNC(tail_swap)(pta, swap, nmemb, cmp);
	}
	else if (FUNC(quad_swap)(pta, nmemb, cmp) == 0)
	{
		VAR *swap = NULL;
		size_t block, swap_size = nmemb;

//		for (swap_size = 32 ; swap_size * 4 <= nmemb ; swap_size *= 4) {}

		swap = (VAR *) malloc(swap_size * sizeof(VAR));

		if (swap == NULL)
		{
            O("sort: branch2 no allocator\n");
			VAR stack[512];

			FUNC(tail_merge)(pta, stack, 32, nmemb, 32, cmp);

			FUNC(rotate_merge)(pta, stack, 32, nmemb, 64, cmp);

			return;
		}
		O("sort: branch1 with allocator\n");
		block = FUNC(quad_merge)(pta, swap, swap_size, nmemb, 32, cmp);

		FUNC(rotate_merge)(pta, swap, swap_size, nmemb, block, cmp);

		free(swap);
	}
}

void FUNC(quadsort_swap)(void *array, void *swap, size_t swap_size, size_t nmemb, CMPFUNC *cmp)
{
    O("quadsort_swap: ss=%zu, n=%zu\n", swap_size, nmemb);
	VAR *pta = (VAR *) array;
	VAR *pts = (VAR *) swap;

	if (nmemb <= 96)
	{
		FUNC(tail_swap)(pta, pts, nmemb, cmp);
	}
	else if (FUNC(quad_swap)(pta, nmemb, cmp) == 0)
	{
		size_t block = FUNC(quad_merge)(pta, pts, swap_size, nmemb, 32, cmp);

		FUNC(rotate_merge)(pta, pts, swap_size, nmemb, block, cmp);
	}
}