/*
 * This file and its contents are licensed under the Timescale License.
 * Please see the included NOTICE for copyright information and
 * LICENSE-TIMESCALE for a copy of the license.
 */
#pragma once

#include <adts/bit_array.h>

/*
 * This is a specialization of Simple8bRLE decoder for encoded 1 bit values
 * as they are used to store NULLs in the compression methods as well as
 * the values for bool compression. The only difference is the way we encode
 * nulls, where in bool compression we store 1 in the validity map while in
 * other compressions we store 0 in the null map.
 * 
 * The goal of this decoder is to support the decoding ino Arrow array validity
 * maps, which is a bitmap with 1s for non-nulls, so we need to invert the
 * content bits.
 * 
 * The reason we don't use the Simple8bRleBitmap is that the end result is an
 * array of bits and not bools.
 * 
 * The complication comes from the RLE encoding of Simple8b while in the Arrow
 * validity bitmaps we have a straigh array of bits. The BitArray has handy
 * functions to work with whole 64bit values, so we can make the decoding
 * efficient.
 */

typedef struct Simple8bRleBitArray
{
	BitArray bits;
	uint16 num_ones;
} Simple8bRleBitArray;

