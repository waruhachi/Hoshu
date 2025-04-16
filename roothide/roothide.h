#ifndef ROOTHIDE_H
#define ROOTHIDE_H

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wnullability-completeness"

#include <string.h>
#include <unistd.h>

#ifdef __cplusplus
#include <string>
#endif

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

// stub functions

#ifdef __cplusplus
extern "C" {
#endif

static unsigned long long jbrand() { return 0; }
static const char *jbroot(const char *path) {
  if (!path || !*path || path[0] != '/') {
    return path;
  }
  static char __thread buffer[PATH_MAX];
  snprintf(buffer, sizeof(buffer), "/var/jb%s", path);
  return buffer;
}
static const char *rootfs(const char *path) { return path; }

#ifdef __OBJC__
static NSString *_Nonnull __attribute__((overloadable))
jbroot(NSString *_Nonnull path) {
  return [@"/var/jb" stringByAppendingPathComponent:path];
}
static NSString *_Nonnull __attribute__((overloadable))
rootfs(NSString *_Nonnull path) {
  return path;
}
#endif

#ifdef __cplusplus
}
#endif

#pragma GCC diagnostic pop

#endif /* ROOTHIDE_H */