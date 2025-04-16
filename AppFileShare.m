//
//  AppFileShare.m
//  Sileo
//
//  Created by admin on 7/5/2024.
//  Copyright © 2024 Sileo Team. All rights reserved.
//

#include <Foundation/Foundation.h>

@interface LSApplicationProxy : NSObject
@property(nonatomic, readonly) NSString *applicationIdentifier;
@property(nonatomic, readonly) NSDictionary *groupContainerURLs;

- (NSURL *)bundleURL;
- (NSURL *)containerURL;
- (NSURL *)dataContainerURL;
- (NSString *)teamID;
- (NSString *)vendorName;
- (NSString *)applicationType;
- (NSString *)bundleExecutable;
- (NSString *)bundleIdentifier;
- (id)correspondingApplicationRecord;
- (id)localizedNameForContext:(id)arg1;
- (BOOL)isDeletable;
- (NSSet *)claimedURLSchemes;
- (NSDictionary *)environmentVariables;
+ (id)applicationProxyForIdentifier:(id)arg1;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (id)operationToOpenResource:(id)arg1
             usingApplication:(id)arg2
                     userInfo:(id)arg3;
@end

BOOL IsAppAvailable(NSString *bundleId) {
  LSApplicationProxy *app =
      [LSApplicationProxy applicationProxyForIdentifier:bundleId];
  return app && app.bundleExecutable;
}

BOOL ShareFileToApp(NSString *bundleId, NSString *filePath) {
  LSApplicationProxy *app =
      [LSApplicationProxy applicationProxyForIdentifier:bundleId];

  if (!app || !app.bundleExecutable)
    return NO;

  NSOperation *op = [[LSApplicationWorkspace defaultWorkspace]
      operationToOpenResource:[NSURL fileURLWithPath:filePath]
             usingApplication:[app applicationIdentifier]
                     userInfo:nil];
  if (!op)
    return NO;
  [op start];

  return YES;
}
