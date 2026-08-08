#ifndef __LINUX_COMPILER_H
#error "Please don't include <linux/compiler-gcc12.h> directly, include <linux/compiler.h> instead."
#endif

/* Compatibility header for Linux 3.0.x with a modern GCC. */

#if __GNUC_MINOR__ == 1 && __GNUC_PATCHLEVEL__ <= 1
# error Your version of gcc miscompiles the __weak directive
#endif

#define __used                  __attribute__((__used__))
#define __must_check            __attribute__((warn_unused_result))
#define __compiler_offsetof(a,b) __builtin_offsetof(a,b)
#define __cold                  __attribute__((__cold__))
#define unreachable()           __builtin_unreachable()
#define __noclone               __attribute__((__noclone__))
#define __compiletime_object_size(obj) __builtin_object_size(obj, 0)

#if !defined(__CHECKER__)
#define __compiletime_warning(message) __attribute__((warning(message)))
#define __compiletime_error(message) __attribute__((error(message)))
#endif
