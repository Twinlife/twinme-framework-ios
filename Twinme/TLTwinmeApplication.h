/*
 *  Copyright (c) 2016-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLTwinlifeContext.h>

//
// Interface: TLTwinmeApplication
//

@protocol TLNotificationCenter;
@class TLTwinmeContext;
@class TLProfile;

typedef enum {
    TLTwinmeApplicationFeatureGroupCall
} TLTwinmeApplicationFeature;

@interface TLTwinmeApplication : NSObject

@property (readonly) BOOL isRunning;

- (void)stop;

- (void)restart;

- (void)setDefaultProfileWithProfile:(nonnull TLProfile *)profile;

- (nonnull id<TLNotificationCenter>)allocNotificationCenterWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext;

/// Check if the feature is enabled for the application.
- (BOOL)isSubscribedWithFeature:(TLTwinmeApplicationFeature)feature;

/// Get the connection status
- (TLConnectionStatus)connectionStatus;

@end
