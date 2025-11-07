/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLFilter.h>

#import "TLProfile.h"
#import "TLSpace.h"
#import "TLAbstractTwinmeExecutor.h"
#import "TLGetSpacesExecutor.h"
#import "TLTwinmeContextImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.3
//

static const int GET_SPACE_SETTINGS = 1 << 0;
static const int GET_SPACE_SETTINGS_DONE = 1 << 1;
static const int GET_SPACES = 1 << 2;
static const int GET_SPACES_DONE = 1 << 3;
static const int GET_PROFILES = 1 << 4;
static const int GET_PROFILES_DONE = 1 << 5;
static const int CREATE_SPACE = 1 << 6;
static const int CREATE_SPACE_DONE = 1 << 7;
static const int UPDATE_PROFILE = 1 << 8;
static const int UPDATE_PROFILE_DONE = 1 << 9;

//
// Interface: TLGetSpacesExecutor ()
//

@class TLSpace;
@class TLProfile;
@class TLGetSpacesExecutorTwinmeContextDelegate;

@interface TLGetSpacesExecutor ()

@property (nonatomic, readonly, nonnull) NSUUID *spaceId;
@property (nonatomic, readonly, nonnull) NSMutableArray<TLSpace *> *spaces;
@property (nonatomic, readonly, nonnull) NSMutableArray<TLProfile *> *profiles;
@property (nonatomic, readonly) BOOL enableSpaces;

@property (nonatomic, nullable) TLSpace *defaultSpace;
@property (nonatomic, nullable) NSMutableArray<TLProfile *> *updateProfiles;
@property (nonatomic, nullable) NSMutableArray<TLSpace *> *spaceToDelete;

@property (nonatomic, readonly, nonnull) TLGetSpacesExecutorTwinmeContextDelegate *twinmeContextDelegate;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onListSpaceSettings:(nullable NSArray<id<TLRepositoryObject>> *)list errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onListSpaces:(nullable NSArray<id<TLRepositoryObject>> *)list errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onListProfiles:(nullable NSArray<id<TLRepositoryObject>> *)list errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateSpace:(nonnull TLSpace *)space;

- (void)onUpdateProfile:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (nullable TLProfile *)getDefaultProfile;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: TLGetSpacesExecutorTwinmeContextDelegate
//

@interface TLGetSpacesExecutorTwinmeContextDelegate:NSObject <TLTwinmeContextDelegate>

@property (nullable) TLGetSpacesExecutor* executor;

- (instancetype)initWithExecutor:(TLGetSpacesExecutor *)executor;

- (void)dispose;

@end

//
// Implementation: TLGetSpacesExecutorTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLGetSpacesExecutorTwinmeContextDelegate"

@implementation TLGetSpacesExecutorTwinmeContextDelegate

- (instancetype)initWithExecutor:(TLGetSpacesExecutor *)executor {
    DDLogVerbose(@"%@ initWithExecutor: %@", LOG_TAG, executor);
    
    self = [super init];
    if (self) {
        _executor = executor;
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    self.executor = nil;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    if (self.executor) {
        [self.executor onTwinlifeReady];
        [self.executor onOperation];
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.executor) {
        [self.executor onTwinlifeOnline];
        [self.executor onOperation];
    }
}

- (void)onTwinlifeOffline {
    DDLogVerbose(@"%@ onTwinlifeOffline", LOG_TAG);
    
    if (self.executor) {
        [self.executor onTwinlifeOffline];
    }
}

- (void)onCreateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    if (self.executor) {
        NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
        NSNumber *operationId = self.executor.requestIds[lRequestId];
        if (operationId != nil) {
            [self.executor.requestIds removeObjectForKey:lRequestId];
            [self.executor onCreateSpace:space];
            [self.executor onOperation];
        }
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    if (self.executor) {
        NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
        NSNumber *operationId = self.executor.requestIds[lRequestId];
        if (operationId != nil) {
            [self.executor.requestIds removeObjectForKey:lRequestId];
            [self.executor onErrorWithOperationId:operationId.intValue errorCode:errorCode errorParameter:errorParameter];
            [self.executor onOperation];
        }
    }
}

@end

//
// Implementation: TLGetSpacesExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLGetSpacesExecutor"

@implementation TLGetSpacesExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId enableSpaces:(BOOL)enableSpaces {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld enableSpaces: %d", LOG_TAG, twinmeContext, requestId, enableSpaces);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId];
    if (self) {

        _profiles = [[NSMutableArray alloc] init];
        _spaces = [[NSMutableArray alloc] init];
        _enableSpaces = enableSpaces;

        _twinmeContextDelegate = [[TLGetSpacesExecutorTwinmeContextDelegate alloc] initWithExecutor:self];
    }
    return self;
}

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);
    
    [self.twinmeContext addDelegate:self.twinmeContextDelegate];
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
        
        if ((self.state & GET_SPACES) != 0 && (self.state & GET_SPACES_DONE) == 0) {
            self.state &= ~GET_SPACES;
        }
        if ((self.state & GET_PROFILES) != 0 && (self.state & GET_PROFILES_DONE) == 0) {
            self.state &= ~GET_PROFILES;
        }
    }
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Step 1: load the space settings first.
    //
    if ((self.state & GET_SPACE_SETTINGS) == 0) {
        self.state |= GET_SPACE_SETTINGS;
        
        DDLogVerbose(@"%@ listObjectsWithFactory: %@", LOG_TAG, [TLSpaceSettings SCHEMA_ID]);
        [[self.twinmeContext getRepositoryService] listObjectsWithFactory:[TLSpaceSettings FACTORY] filter:nil withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            [self onListSpaceSettings:list errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & GET_SPACE_SETTINGS_DONE) == 0) {
        return;
    }

    //
    // Step 2: get the list of spaces.
    //
    if ((self.state & GET_SPACES) == 0) {
        self.state |= GET_SPACES;

        DDLogVerbose(@"%@ listObjectsWithFactory: %@", LOG_TAG, [TLSpace SCHEMA_ID]);
        [[self.twinmeContext getRepositoryService] listObjectsWithFactory:[TLSpace FACTORY] filter:nil withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            [self onListSpaces:list errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & GET_SPACES_DONE) == 0) {
        return;
    }

    //
    // Step 3: get the list of profiles.
    //
    if ((self.state & GET_PROFILES) == 0) {
        self.state |= GET_PROFILES;

        DDLogVerbose(@"%@ listObjectsWithFactory: %@", LOG_TAG, [TLProfile SCHEMA_ID]);
        [[self.twinmeContext getRepositoryService] listObjectsWithFactory:[TLProfile FACTORY] filter:nil withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            [self onListProfiles:list errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & GET_PROFILES_DONE) == 0) {
        return;
    }

    //
    // Step 5: create the default space.
    //
    if (!self.defaultSpace && self.profiles.count > 0) {
        
        if ((self.state & CREATE_SPACE) == 0) {
            TLProfile *profile = [self getDefaultProfile];
            self.state |= CREATE_SPACE;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, profile, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

            int64_t requestId = [self newOperation:CREATE_SPACE];
            TLSpaceSettings *settings = [self.twinmeContext defaultSpaceSettings];

            DDLogVerbose(@"%@ createDefaultSpaceWithRequestId: %lld settings: %@ profile: %@", LOG_TAG, requestId, settings, profile);
            [self.twinmeContext createDefaultSpaceWithRequestId:requestId settings:settings profile:profile];
            return;
        }
        if ((self.state & CREATE_SPACE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 6: check that each profile has a space.
    //
    if (self.profiles.count > 0) {
        
        if ((self.state & CREATE_SPACE) == 0) {
            TLProfile *profile = self.profiles[0];
            self.state |= CREATE_SPACE;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, profile, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

            int64_t requestId = [self newOperation:CREATE_SPACE];
            TLSpaceSettings *settings = [self.twinmeContext defaultSpaceSettings];

            settings.name = profile.name;

            DDLogVerbose(@"%@ createSpaceWithRequestId: %lld settings: %@ profile: %@", LOG_TAG, requestId, settings, profile);
            [self.twinmeContext createSpaceWithRequestId:requestId settings:settings profile:profile];
            return;
        }
        if ((self.state & CREATE_SPACE_DONE) == 0) {
            return;
        }
    }
    
    if (self.updateProfiles) {
        if ((self.state & UPDATE_PROFILE) == 0) {
            self.state |= UPDATE_PROFILE;

            [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.updateProfiles[0] localOnly:YES withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
                [self onUpdateProfile:object errorCode:errorCode];
            }];
            return;
        }
        
        if ((self.state & UPDATE_PROFILE_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step
    //

    [self.twinmeContext onGetSpacesWithRequestId:self.requestId spaces:self.spaces];
    [self stop];
}

- (void)onListSpaceSettings:(nullable NSArray<id<TLRepositoryObject>> *)list errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onListSpaceSettings: %d list=%@", LOG_TAG, errorCode, list);

    // Ignore errors as well as the list: the space settings are now loaded in the database service cache.
    self.state |= GET_SPACE_SETTINGS_DONE;
    [self onOperation];
}

- (void)onListSpaces:(nullable NSArray<id<TLRepositoryObject>> *)list errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onListSpaces: %d list=%@", LOG_TAG, errorCode, list);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || list == nil) {
        
        [self onErrorWithOperationId:GET_SPACES errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= GET_SPACES_DONE;
    for (id<TLRepositoryObject> object in list) {
        TLSpace *space = (TLSpace *)object;
        [self.spaces addObject:space];
        if ([self.twinmeContext isDefaultSpace:space]) {
            self.defaultSpace = space;
        }
    }

    // Make sure we know a default space.
    if (!self.defaultSpace && self.spaces.count > 0) {
        self.defaultSpace = self.spaces[0];
    }
    [self onOperation];
}

- (void)onListProfiles:(nullable NSArray<id<TLRepositoryObject>> *)list errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onListProfiles: %d list=%@", LOG_TAG, errorCode, list);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || list == nil) {
        
        [self onErrorWithOperationId:GET_PROFILES errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= GET_PROFILES_DONE;

    NSMutableDictionary<NSUUID *, TLProfile *> *profiles = [[NSMutableDictionary alloc] init];
    for (id<TLRepositoryObject> object in list) {
        TLProfile *profile = (TLProfile *)object;
        [profiles setObject:profile forKey:profile.uuid];
        if (!profile.space) {
            // Find a space that could reference the profile.
            // If we find it, we must save the profile to keep the link to the space in the database.
            for (TLSpace *space in self.spaces) {
                if ([profile.uuid isEqual:space.profileId]) {
                    space.profile = profile;
                    profile.space = space;
                    if (!self.updateProfiles) {
                        self.updateProfiles = [[NSMutableArray alloc] init];
                    }
                    [self.updateProfiles addObject:profile];
                    break;
                }
            }
            if (!profile.space) {
                [self.profiles addObject:profile];
            }
        }
    }

    // Due to bug Twinme/twinme-framework-ios#28, a profile could be used by several spaces.
    // This occurred mostly on profiles created and associated with a levelId before 2020.
    // Identify the profiles which are shared betwen several spaces.
    // Because the profile now links to the space in the database, it could have been associated
    // with one of these duplicate space, and may be not the correct one after the migration.
    // - step1: find profiles without a space.
    // - step2: drop spaces
    if (profiles.count > 0 && self.spaces.count > 1) {
        [self checkWithProfiles:profiles];
    }

    [self onOperation];
}

- (void)checkWithProfiles:(nonnull NSDictionary<NSUUID *, TLProfile *> *)profiles {
    DDLogVerbose(@"%@ checkProfiles", LOG_TAG);

    NSMutableDictionary<NSUUID *, NSMutableArray<TLSpace*> *> *usedProfiles = [[NSMutableDictionary alloc] initWithCapacity:self.spaces.count];
    NSMutableArray<NSMutableArray<TLSpace *> *> *duplicateSpaces = nil;
    for (TLSpace *space in self.spaces) {
        NSUUID *profileId = space.profileId;
        if (profileId) {
            NSMutableArray<TLSpace*> *list = usedProfiles[profileId];
            if (!list) {
                list = [[NSMutableArray alloc] init];
                [usedProfiles setObject:list forKey:profileId];
            } else {
                if (!duplicateSpaces) {
                    duplicateSpaces = [[NSMutableArray alloc] init];
                }
                if (![duplicateSpaces containsObject:list]) {
                    [duplicateSpaces addObject:list];
                }
            }
            [list addObject:space];
        }
    }

    // For each group of space (linked to the same profile), find the oldest space and assume
    // all contacts/groups are linked to it.  The duplicace spaces are not exposed and are also
    // removed from the self.spaces so that we don't return them.
    // BUT, there could be some contact/group associated with these duplicate/faulty spaces and
    // we MUST NOT drop them.
    if (duplicateSpaces) {
        DDLogWarn(@"%@ found %ld duplicate spaces for same profile", LOG_TAG, duplicateSpaces.count);

        self.spaceToDelete = [[NSMutableArray alloc] init];
        for (NSMutableArray<TLSpace *> *list in duplicateSpaces) {
            // Identify the oldest space.
            TLSpace *oldestSpace = nil;
            TLProfile *profile = nil;
            for (TLSpace *space in list) {
                if (!profile && space.profile) {
                    profile = space.profile;
                }
                if (!oldestSpace) {
                    oldestSpace = space;
                } else if (space.creationDate < oldestSpace.creationDate) {
                    [self.spaceToDelete addObject:oldestSpace];
                    [self.spaces removeObject:oldestSpace];
                    oldestSpace = space;
                } else {
                    [self.spaceToDelete addObject:space];
                    [self.spaces removeObject:space];
                }
            }
            if (oldestSpace && !oldestSpace.profile) {
                if (!profile) {
                    oldestSpace.profile = profiles[oldestSpace.profileId];
                } else {
                    oldestSpace.profile = profile;
                }
            }
        }
        DDLogWarn(@"%@ there are %ld space to delete", LOG_TAG, self.spaceToDelete.count);
    }
}

- (void)onCreateSpace:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpace: %@", LOG_TAG, space);

    self.state |= CREATE_SPACE_DONE;

    // Take into account every profile associated with this space.  There should be only one
    // except for the migration of some users which could have several profiles for the same space.
    for (long i = self.profiles.count; i > 0; ) {
        i--;
        
        TLProfile *profile = self.profiles[i];
        if (profile == space.profile) {
            profile.space = space;
            // Assign this profile to the space if there is none or it is less priority.
            if (!space.profile || (space.profile.priority < profile.priority)) {
                space.profile = profile;
            }

            // When spaces are disabled, we can have multiple profiles per space:
            // remove them since they are assigned to this space.
            if (!self.enableSpaces) {
                [self.profiles removeObjectAtIndex:i];
            }
        }
    }

    if (self.enableSpaces && space.profile) {
        [self.profiles removeObject:space.profile];
    }
    [self.spaces addObject:space];

    if ([self.twinmeContext isDefaultSpace:space]) {
        self.defaultSpace = space;
    }
    if (self.profiles.count > 0) {
        self.state &= ~CREATE_SPACE;
        self.state &= ~CREATE_SPACE_DONE;
    }
}

- (void)onUpdateProfile:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateProfile: %d object: %@", LOG_TAG, errorCode, object);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:UPDATE_PROFILE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_PROFILE_DONE;
    [self.updateProfiles removeObjectAtIndex:0];
    if (self.updateProfiles.count > 0) {
        self.state &= ~(UPDATE_PROFILE | UPDATE_PROFILE_DONE);
    }
    [self onOperation];
}

- (TLProfile *)getDefaultProfile {
    DDLogVerbose(@"%@ getDefaultProfile", LOG_TAG);

    TLProfile *result = nil;
    for (TLProfile *profile in self.profiles) {
        if ((!result || result.priority < profile.priority)) {
            result = profile;
        }
    }
    return result;
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        if (operationId == GET_PROFILES) {
            // If we get the Offline error on the getObjectIds operation, the local database does not contain any profile.
            // We MUST proceed with the space objects because a space may exist without a profile.
            self.state |= GET_PROFILES_DONE;
            return;
        }

        if (operationId == GET_SPACES && self.profiles.count == 0) {
            // If we get the Offline error on the getObjectIdsWithRequestId operation, the local database does not contain any space.
            [self.twinmeContext onGetSpacesWithRequestId:self.requestId spaces:self.spaces];
            [self stop];
            return;
        }

        self.restarted = YES;
        return;
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
    [self.twinmeContextDelegate dispose];
    
    [super stop];
}

@end
