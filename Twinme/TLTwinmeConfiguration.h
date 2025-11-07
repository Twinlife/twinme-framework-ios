/*
*  Copyright (c) 2020-2025 twinlife SA.
*  SPDX-License-Identifier: AGPL-3.0-only
*
*  Contributors:
*   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
*   Stephane Carrez (Stephane.Carrez@twin.life)
*/

#import <Twinlife/TLTwinlife.h>

//
// Interface: TLTwinmeConfiguration
//
@interface TLTwinmeConfiguration : TLTwinlifeConfiguration
@property (readonly) BOOL enableReports;
@property (readonly) BOOL enableInvocations;
@property (readonly) BOOL enableSpaces;
@property (readonly) NSTimeInterval refreshBadgeDelay;

- (nonnull instancetype)initWithName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion serializers:(nonnull NSArray<TLSerializer *> *)serializers enableKeepAlive:(BOOL)enableKeepAlive enableSetup:(BOOL)enableSetup enableCaches:(BOOL)enableCaches enableReports:(BOOL)enableReports enableInvocations:(BOOL)enableInvocations enableSpaces:(BOOL)enableSpaces refreshBadgeDelay:(NSTimeInterval)refreshBadgeDelay;

@end
