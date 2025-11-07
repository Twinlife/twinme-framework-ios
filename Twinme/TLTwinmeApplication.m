/*
 *  Copyright (c) 2016-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <WebRTC/RTCAudioSession.h>
#import <WebRTC/RTCAudioSessionConfiguration.h>

#import <Twinlife/TLAccountService.h>

#import "TLTwinmeApplication.h"
#import "TLTwinmeContext.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLTwinmeApplication ()
//

@interface TLTwinmeApplication ()

@property (nullable) TLTwinmeContext *twinmeContext;

@end

//
// Implementation: TLTwinmeApplication
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeApplication"

@implementation TLTwinmeApplication
@synthesize isRunning = _isRunning;

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super init];
    if (self) {
        _isRunning = YES;
    }
    return self;
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);
    
    _isRunning = NO;
}

- (void)restart {
    DDLogVerbose(@"%@ restart", LOG_TAG);
}

- (void)setDefaultProfileWithProfile:(TLProfile *)profile {
    DDLogVerbose(@"%@ setDefaultProfileWithProfile: %@", LOG_TAG, profile);
}

- (id<TLNotificationCenter>)allocNotificationCenterWithTwinmeContext:(TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ allocNotificationCenterWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self.twinmeContext = twinmeContext;
    return nil;
}

- (BOOL)isSubscribedWithFeature:(TLTwinmeApplicationFeature)feature {
    DDLogVerbose(@"%@ isSubscribedWithFeature: %d", LOG_TAG, feature);

    if (!self.twinmeContext) {

        return NO;
    }

    TLAccountService *accountService = [self.twinmeContext getAccountService];
    if (feature == TLTwinmeApplicationFeatureGroupCall) {
        return [accountService isFeatureSubscribedWithName:@"group-call"];
    }

    return NO;
}

- (TLConnectionStatus)connectionStatus {
    DDLogVerbose(@"%@ connectionStatus", LOG_TAG);
    
    if (!self.twinmeContext) {
        return TLConnectionStatusNoService;
    } else {
        return [self.twinmeContext connectionStatus];
    }
}

@end
