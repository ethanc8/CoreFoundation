/*	CFBigNumber.h
	Copyright (c) 2012-2019, Apple Inc. and the Swift project authors
 
	Portions Copyright (c) 2014-2019, Apple Inc. and the Swift project authors
	Licensed under Apache License v2.0 with Runtime Library Exception
	See http://swift.org/LICENSE.txt for license information
	See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
*/

#if !defined(__COREFOUNDATION_CFBIGNUMBER__)
#define __COREFOUNDATION_CFBIGNUMBER__ 1

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFNumber.h>

// size_t
#include <stddef.h>

// Base 1 billion number: each digit represents 0 to 999999999
typedef struct {
    uint32_t digits[5];
    int32_t sign:8;
    uint32_t __:24;
} _CFBigNum;

void _CFBigNumInitWithInt8(_CFBigNum *r, int8_t inNum);
void _CFBigNumInitWithInt16(_CFBigNum *r, int16_t inNum);
void _CFBigNumInitWithInt32(_CFBigNum *r, int32_t inNum);
void _CFBigNumInitWithInt64(_CFBigNum *r, int64_t inNum);
#if TARGET_RT_64_BIT
void _CFBigNumInitWithInt128(_CFBigNum *r, __int128_t inNum);
#endif

void _CFBigNumInitWithUInt8(_CFBigNum *r, uint8_t inNum);
void _CFBigNumInitWithUInt16(_CFBigNum *r, uint16_t inNum);
void _CFBigNumInitWithUInt32(_CFBigNum *r, uint32_t inNum);
void _CFBigNumInitWithUInt64(_CFBigNum *r, uint64_t inNum);
#if TARGET_RT_64_BIT
void _CFBigNumInitWithUInt128(_CFBigNum *r, __uint128_t inNum);
#endif

int8_t  _CFBigNumGetInt8(const _CFBigNum *num);
int16_t _CFBigNumGetInt16(const _CFBigNum *num);
int32_t _CFBigNumGetInt32(const _CFBigNum *num);
int64_t _CFBigNumGetInt64(const _CFBigNum *num);
#if TARGET_RT_64_BIT
__int128_t _CFBigNumGetInt128(const _CFBigNum *num);
#endif

uint8_t  _CFBigNumGetUInt8(const _CFBigNum *num);
uint16_t _CFBigNumGetUInt16(const _CFBigNum *num);
uint32_t _CFBigNumGetUInt32(const _CFBigNum *num);
uint64_t _CFBigNumGetUInt64(const _CFBigNum *num);
#if TARGET_RT_64_BIT
__uint128_t _CFBigNumGetUInt128(const _CFBigNum *num);
#endif

void _CFBigNumInitWithCFNumber(_CFBigNum *r, CFNumberRef input);
void _CFBigNumInitWithBytes(_CFBigNum *r, const void *bytes, CFNumberType type);
CFNumberRef _CFNumberCreateWithBigNum(const _CFBigNum *input);


CFComparisonResult _CFBigNumCompare(const _CFBigNum *a, const _CFBigNum *b);

void _CFBigNumNeg(_CFBigNum *r, const _CFBigNum *a);
uint8_t _CFBigNumAdd(_CFBigNum *r, const _CFBigNum *a, const _CFBigNum *b);
uint8_t _CFBigNumSub(_CFBigNum *r, const _CFBigNum *a, const _CFBigNum *b);


void _CFBigNumToCString(const _CFBigNum *vp, Boolean leading_zeros, Boolean leading_plus, char *buffer, size_t buflen);
void _CFBigNumFromCString(_CFBigNum *r, const char *string);

char *_CFBigNumCopyDescription(const _CFBigNum *num); // caller must free() returned ptr


#endif /* ! __COREFOUNDATION_CFBIGNUMBER__ */

