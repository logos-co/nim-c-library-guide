/**
* libvcache.h - C Interface for Example Library
*
* This header provides the public API for libvcache
*
* IMPLEMENTATION STEPS:
* 1. Rename this file to `lib<your_library_name>.h`
* 2. Replace "vcache" in all function names with your library name
* 3. Rename the VCacheCallBack type to <YourLibraryName>Callback
* 4. Replace the vcache functions with your library's specific functions
* 5. Update the header guards to match your library name
*
* See additional TODO comments throughout the file for specific guidance.
*
* To see the auto-generated header by Nim, run `make libvcache` from the
* repository root. The generated file will be created at:
* nimcache/release/libvcache/libvcache.h
*/

// TODO: change vcache for your library's name
#ifndef __libvcache__
#define __libvcache__

#include <stddef.h>
#include <stdint.h>

// The possible returned values for the functions that return int
#define RET_OK                0
#define RET_ERR               1
#define RET_MISSING_CALLBACK  2

#ifdef __cplusplus
extern "C" {
#endif

// TODO: change VCacheCallback to <YourLibraryName>Callback
typedef void (*VCacheCallBack) (int callerRet, const char* msg, size_t len, void* userData);

// TODO: replace the vcache functions for your library's functions
// TODO: replace the VCacheCallBack parameter for <YourLibraryName>Callback
void* vcache_new(
             const char* configJson,
             VCacheCallBack callback,
             void* userData);

int vcache_destroy(void* ctx,
                 VCacheCallBack callback,
                 void* userData);

void vcache_set_event_callback(void* ctx,
                             VCacheCallBack callback,
                             void* userData);

#ifdef __cplusplus
}
#endif

// TODO: change vcache for your library's name
#endif /* __libvcache__ */