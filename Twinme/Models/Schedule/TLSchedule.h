/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Foundation/NSTimeZone.h>
#import "TLTimeRange.h"

@interface TLSchedule : NSObject

@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL isPrivate;
@property (nonnull, nonatomic) NSTimeZone *timeZone;
@property (nonnull, nonatomic) NSArray<id<TLTimeRange>> *timeRanges;

- (nonnull instancetype) initWithPrivate:(BOOL)isPrivate timeZone:(nonnull NSTimeZone *)timeZone timeRanges:(nonnull NSArray<id<TLTimeRange>> *)timeRanges;

+ (nullable instancetype)ofCapabilityWithCapabilityString:(nonnull NSString *)capability;

- (nonnull NSString *) toCapability;

- (BOOL) isNowInRange;

- (BOOL) isTimestampInRangeWithTimestamp:(long)timestamp;

@end
