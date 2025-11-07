/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLTimeRange.h"

@implementation TLDateTimeRange: NSObject

- (nonnull instancetype)initWithStart:(nonnull TLDateTime *)start end:(nonnull TLDateTime *)end {
    self = [super init];
    if(self){
        _start = start;
        _end = end;
    }
    return self;
}

- (nonnull instancetype)initWithDateTimeRangeString:(nonnull NSString *)timeRange {
    NSArray<NSString *> *split = [timeRange componentsSeparatedByString:@","];
    
    if(split.count != 3){
        @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"Invalid DateTimeRange" userInfo:@{@"timeRange": timeRange}];
    }
    
    self = [super init];
    if(self){
        _start = [[TLDateTime alloc] initWithDateTimeString:split[1]];
        _end = [[TLDateTime alloc] initWithDateTimeString:split[2]];
    }
    
    return self;
}

- (BOOL)isTimestampInRangeWithTimeStamp:(long)timestamp timeZone:(nonnull NSTimeZone *)timeZone {
    NSDate* date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];
    
    NSDate *start = [self.start toNSDateWithTimeZone:timeZone];
    NSDate *end = [self.end toNSDateWithTimeZone:timeZone];
    
    NSDateInterval *interval = [[NSDateInterval alloc] initWithStartDate:start endDate:end];
    
    return [interval containsDate:date];
}

- (nonnull NSString *)serialize {
    return [NSString stringWithFormat:@"%@,%@,%@", DATE_TIME_RANGE_SERIALIZATION_PREFIX, [self.start toString], [self.end toString]];
}

- (BOOL) isEqual:(nullable id)object {
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLDateTimeRange class]]) {
        return NO;
    }
    
    TLDateTimeRange *timeRange = (TLDateTimeRange *)object;
    
    return [self.start isEqual:timeRange.start] && [self.end isEqual:timeRange.end];
}

- (NSUInteger) hash {
    NSUInteger result = 17;
    result = 31 * result + self.start.hash;
    result = 31 * result + self.end.hash;
    return result;
}

- (NSComparisonResult)compare:(nonnull id<TLTimeRange>)timeRange {
    if([timeRange class] == [TLWeeklyTimeRange class]){
        return NSOrderedAscending;
    }
    
    TLDateTimeRange *o = (TLDateTimeRange *)timeRange;
    
    NSComparisonResult res = [self.start compare:o.start];
    
    if(res == NSOrderedSame){
        res = [self.end compare:o.end];
    }
    
    return res;
}

@end
