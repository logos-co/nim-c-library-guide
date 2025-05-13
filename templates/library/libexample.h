/**
* libexample.h - C Interface for Example Library
*
* This header provides the public API for libexample, allowing integration
* from C and C++ applications. The interface follows standard C calling
* conventions and provides asynchronous callback-based operations.
*
* IMPLEMENTATION STEPS:
* 1. Rename this file to `lib<your_library_name>.h`
* 2. Replace "example" in all function names with your library name
* 3. Rename the ExampleCallBack type to <YourLibraryName>Callback
* 4. Replace the example functions with your library's specific functions
* 5. Update the header guards to match your library name
*
* See additional TODO comments throughout the file for specific guidance.
*
* To see the auto-generated header by Nim, run `make libexample` from the
* repository root. The generated file will be created at:
* nimcache/release/libexample/libexample.h
*/

// TODO: change example for your library's name
#ifndef __libexample__
#define __libexample__

#include <stddef.h>
#include <stdint.h>

// The possible returned values for the functions that return int
#define RET_OK                0
#define RET_ERR               1
#define RET_MISSING_CALLBACK  2

#ifdef __cplusplus
extern "C" {
#endif

// TODO: change ExampleCallback to <YourLibraryName>Callback
typedef void (*ExampleCallBack) (int callerRet, const char* msg, size_t len, void* userData);

// TODO: replace the example functions for your library's functions
// TODO: replace the ExampleCallBack parameter for <YourLibraryName>Callback
void* example_new(
             const char* configJson,
             ExampleCallBack callback,
             void* userData);

int example_destroy(void* ctx,
                 ExampleCallBack callback,
                 void* userData);

void example_set_event_callback(void* ctx,
                             ExampleCallBack callback,
                             void* userData);

int example_some_request(void* ctx,
                    void* exampleArray,
                    size_t arrayLen,
                    const char* exampleString,
                    ExampleCallBack callback,
                    void* userData);


#ifdef __cplusplus
}
#endif

// TODO: change example for your library's name
#endif /* __libexample__ */