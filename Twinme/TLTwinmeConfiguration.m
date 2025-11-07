/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLTwinmeConfiguration.h"
#import "TLSpaceSettings.h"
#import "TLSpace.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLCallReceiver.h"
#import "TLProfile.h"
#import "TLInvitation.h"
#import "TLAccountMigration.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLTwinmeConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeConfiguration"

@implementation TLTwinmeConfiguration

- (nonnull instancetype)initWithName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion serializers:(nonnull NSArray<TLSerializer *> *)serializers enableKeepAlive:(BOOL)enableKeepAlive enableSetup:(BOOL)enableSetup enableCaches:(BOOL)enableCaches enableReports:(BOOL)enableReports enableInvocations:(BOOL)enableInvocations enableSpaces:(BOOL)enableSpaces refreshBadgeDelay:(NSTimeInterval)refreshBadgeDelay {
    DDLogVerbose(@"%@ initWithServiceId", LOG_TAG);
    
    // The repository object factories in the order in which they are migrated.
    self = [super initWithName:applicationName applicationVersion:applicationVersion serializers:serializers enableSetup:enableSetup enableCaches:enableCaches factories:[NSArray arrayWithObjects:[TLSpaceSettings FACTORY], [TLSpace FACTORY], [TLProfile FACTORY], [TLContact FACTORY], [TLGroup FACTORY], [TLInvitation FACTORY], [TLCallReceiver FACTORY], [TLAccountMigration FACTORY], nil]];
    if (self) {
        _enableReports = enableReports;
        _enableInvocations = enableInvocations;
        _enableSpaces = enableSpaces;
        _refreshBadgeDelay = refreshBadgeDelay;
    }
    return self;
}

@end
