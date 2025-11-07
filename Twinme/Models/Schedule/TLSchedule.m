/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLSchedule.h"
#import "TLTimeRange.h"

#define CAP_NAME_ENABLED @"en"
#define CAP_NAME_TIMEZONE @"tz"
#define CAP_NAME_TIME_RANGE @"tr"
#define CAP_SEPARATOR @";"

@implementation TLSchedule {
    /// Backing mutable array for timeRanges property
    NSMutableArray *_timeRanges;
    NSTimeZone *_timeZone;
}


- (nonnull instancetype)initWithPrivate:(BOOL)isPrivate timeZone:(nonnull NSTimeZone *)timeZone timeRanges:(nonnull NSArray *)timeRanges {
    self = [super init];
    if(self){
        _enabled = YES;
        _isPrivate = isPrivate;
        self.timeZone = timeZone;
        self.timeRanges = timeRanges;
    }
    return self;
}

- (void) addTimeRange:(nonnull id<TLTimeRange>)timeRange {
    @synchronized (self) {
        [_timeRanges addObject:timeRange];
        [self sortTimeRanges];
    }
}

- (void) setTimeRanges:(NSArray<id<TLTimeRange>> *)timeRanges {
    @synchronized (self) {
        _timeRanges = [timeRanges mutableCopy];
        [self sortTimeRanges];
    }
}

- (NSArray<id<TLTimeRange>> *) timeRanges {
    @synchronized (self) {
        return [_timeRanges copy];
    }
}

- (void) setTimeZone:(nonnull NSTimeZone *)timeZone{
    @synchronized (self) {
        _timeZone = timeZone;
    }
}

- (nonnull NSTimeZone *) timeZone {
    @synchronized (self) {
        return _timeZone;
    }
}

- (BOOL)isNowInRange {
    return [self isTimestampInRangeWithTimestamp:[NSDate date].timeIntervalSince1970];
}

- (BOOL)isTimestampInRangeWithTimestamp:(long)timestamp {
    
    if(!self.enabled){
        return YES;
    }
    
    NSArray<id<TLTimeRange>> *timeRanges = self.timeRanges;
    for (id<TLTimeRange> timeRange in timeRanges) {
        if([timeRange isTimestampInRangeWithTimeStamp:timestamp timeZone:self.timeZone]){
            return YES;
        }
    }
    return NO;
}

+ (nullable instancetype)ofCapabilityWithCapabilityString:(nonnull NSString *)capability {
    NSArray<NSString *> *split = [capability componentsSeparatedByString:CAP_SEPARATOR];
    
    BOOL enabled=YES;
    NSTimeZone *timeZone = nil;
    NSMutableArray<id<TLTimeRange>> *timeRanges = [[NSMutableArray alloc] init];
    
    for (NSString *attr in split) {
        if([attr hasPrefix:CAP_NAME_TIMEZONE]){
            NSString *tzName = [TLSchedule getRawCapValueWithLine:attr];
            timeZone = [[NSTimeZone alloc] initWithName:tzName];
        }
        if([attr hasPrefix:CAP_NAME_TIME_RANGE]){
            NSString *timeRange = [TLSchedule getRawCapValueWithLine:attr];
            [timeRanges addObject:[TLSchedule initTimeRangeWithCapabilityString:timeRange]];
        }
        if([attr hasPrefix:CAP_NAME_ENABLED]){
            NSString *enabledValue = [TLSchedule getRawCapValueWithLine:attr];
            enabled = [enabledValue isEqualToString:@"1"];
        }
    }

    if(timeZone && timeRanges.count > 0){
        TLSchedule *res = [[TLSchedule alloc] initWithPrivate:NO timeZone:timeZone timeRanges:timeRanges];
        res.enabled = enabled;
        return res;
    }
    
    return nil;
}

- (nonnull NSString *)toCapability {
    NSMutableString *res = [[NSMutableString alloc] init];
    
    BOOL enabled;
    NSTimeZone *timeZone;
    NSArray<id<TLTimeRange>> *timeRanges;
    
    @synchronized (self) {
        timeZone = self.timeZone;
        timeRanges = self.timeRanges;
        enabled = self.enabled;
    }
    
    [res appendFormat:@"%@=%@", CAP_NAME_ENABLED, enabled ? @"1":@"0"];
    
    [res appendString:CAP_SEPARATOR];
    
    NSString *tzName = timeZone.name;
    if([tzName isEqualToString:@"GMT"]){
        // NSTimeZone's name for UTC is "GMT", whereas it's "UTC" for Java's TimeZone. -initWithName accepts both "UTC" and "GMT".
        tzName = @"UTC";
    }
    
    [res appendFormat:@"%@=%@", CAP_NAME_TIMEZONE, tzName];
    
    for (id<TLTimeRange> timeRange in timeRanges) {
        [res appendString:CAP_SEPARATOR];
        [res appendFormat:@"%@=%@", CAP_NAME_TIME_RANGE, [timeRange serialize]];
    }
    
    return res;
}

- (void)sortTimeRanges {
    [_timeRanges sortUsingComparator:^NSComparisonResult(id<TLTimeRange> _Nonnull tr1, id<TLTimeRange> _Nonnull tr2) {
        return [tr1 compare:tr2];
    }];
}

+ (nonnull NSString *)getRawCapValueWithLine:(nonnull NSString *)line {
    NSArray<NSString *> *split = [line componentsSeparatedByString:@"="];
    
    if (split.count != 2){
        @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"Invalid schedule capability" userInfo:@{@"line": line}];
    }
    
    return split[1];
}

+ (nonnull id<TLTimeRange>)initTimeRangeWithCapabilityString:(nonnull NSString *)capability {
    if([capability hasPrefix:DATE_TIME_RANGE_SERIALIZATION_PREFIX]){
        return [[TLDateTimeRange alloc] initWithDateTimeRangeString:capability];
    }
    
    if([capability hasPrefix:WEEKLY_TIME_RANGE_SERIALIZATION_PREFIX]){
        return [[TLWeeklyTimeRange alloc] initWithWeeklyTimeRangeString:capability];
    }
    
    @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"Unknown time range type" userInfo:@{@"capabilityString": capability}];
}
@end
