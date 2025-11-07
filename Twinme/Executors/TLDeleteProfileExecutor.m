/*
 *  Copyright (c) 2017-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>

#import "TLDeleteProfileExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLProfile.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.10
//

//
// Implementation: TLDeleteProfileExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteProfileExecutor"


@implementation TLDeleteProfileExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId profile:(nonnull TLProfile *)profile timeout:(NSTimeInterval)timeout withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable profileId))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld profile: %@", LOG_TAG, twinmeContext, requestId, profile);
    
    return [super initWithTwinmeContext:twinmeContext requestId:requestId object:profile invocationId:nil timeout:timeout];
}

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object {
    DDLogVerbose(@"%@ onFinishDeleteWithObject: %@", LOG_TAG, object);

    [self.twinmeContext onDeleteProfileWithRequestId:self.requestId profileId:object.uuid];
}

@end

