//
//  Hoshu-Swift-Bridging.h
//  Hoshu
//
//  Created by admin on 4/10/2023.
//

#ifndef Hoshu_Swift_Bridging_h
#define Hoshu_Swift_Bridging_h

#include <spawn.h>
#include <Foundation/Foundation.h>

#include "roothide.h"
#include "AppFileShare.h"

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

#endif /* Hoshu_Swift_Bridging_h */
