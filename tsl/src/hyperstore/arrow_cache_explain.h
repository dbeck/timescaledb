/*
 * This file and its contents are licensed under the Timescale License.
 * Please see the included NOTICE for copyright information and
 * LICENSE-TIMESCALE for a copy of the license.
 */
#pragma once

#include <postgres.h>

#include <nodes/parsenodes.h>

void _arrow_cache_explain_init(void);

extern bool decompress_cache_print;
extern size_t decompress_cache_hits;
extern size_t decompress_cache_misses;

extern bool tsl_process_explain_def(DefElem *opt);
