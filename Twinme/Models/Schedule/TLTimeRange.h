/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Foundation/NSTimeZone.h>
#import "TLDateTime.h"

#define DATE_TIME_RANGE_SERIALIZATION_PREFIX @"dateTime"
#define WEEKLY_TIME_RANGE_SERIALIZATION_PREFIX @"weekly"

//
// Interface TLTimeRange
//
@protocol TLTimeRange <NSObject>
- (nonnull NSString *)serialize;

- (BOOL) isTimestampInRangeWithTimeStamp:(long)timestamp timeZone:(nonnull NSTimeZone *)timeZone;

- (NSComparisonResult) compare:(nonnull id<TLTimeRange>)timeRange;

@end

@interface TLDateTimeRange : NSObject<TLTimeRange>

@property (readonly, nonnull) TLDateTime *start;
@property (readonly, nonnull) TLDateTime *end;

- (nonnull instancetype)initWithStart:(nonnull TLDateTime *)start end:(nonnull TLDateTime *)end;

- (nonnull instancetype)initWithDateTimeRangeString:(nonnull NSString *)dateTimeRange;

@end

@interface TLWeeklyTimeRange : NSObject<TLTimeRange>

@property (readonly, nonnull) NSArray<NSNumber *> *days;
@property (readonly, nonnull) TLTime *start;
@property (readonly, nonnull) TLTime *end;

- (nonnull instancetype)initWithDays:(nonnull NSArray<NSNumber *> *)days start:(nonnull TLTime *)start end:(nonnull TLTime *)end;

- (nonnull instancetype)initWithWeeklyTimeRangeString:(nonnull NSString *)weeklyTimeRange;

@end

typedef enum {
    MONDAY = 1,
    TUESDAY,
    WEDNESDAY,
    THURSDAY,
    FRIDAY,
    SATURDAY,
    SUNDAY
} TLDayOfWeek;
