/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Foundation/NSCalendar.h>
#import "TLTimeRange.h"

@implementation TLWeeklyTimeRange: NSObject

- (nonnull instancetype)initWithDays:(nonnull NSArray<NSNumber *> *)days start:(nonnull TLTime *)start end:(nonnull TLTime *)end {
    self = [super init];
    if(self){
        _days = [[[NSArray alloc] initWithArray: days] sortedArrayUsingSelector:@selector(compare:)];
        
        _start = start;
        _end = end;
    }
    return self;
}

- (nonnull instancetype)initWithWeeklyTimeRangeString:(nonnull NSString *)weeklyTimeRange {
    NSArray<NSString *> *split = [weeklyTimeRange componentsSeparatedByString:@","];
    
    if(split.count != 4){
        @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"Invalid DateTimeRange" userInfo:@{@"timeRange": weeklyTimeRange}];
    }
    
    self = [super init];
    if(self){
        NSArray<NSString *> *daysStr = [split[1] componentsSeparatedByString:@"-"];
        NSMutableArray<NSNumber *> *days = [[NSMutableArray alloc] init];
        for(NSString *day in daysStr){
            [days addObject:@(day.integerValue)];
        }
        _days = [days sortedArrayUsingSelector:@selector(compare:)];
        
        _start = [[TLTime alloc] initWithTimeString:split[2]];
        _end = [[TLTime alloc] initWithTimeString:split[3]];
    }
    
    return self;
}

- (BOOL)isTimestampInRangeWithTimeStamp:(long)timestamp timeZone:(nonnull NSTimeZone *)timeZone {
    NSDate* date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];

    TLDayOfWeek day = [TLWeeklyTimeRange getDayOfWeekWithDate:date timeZone:timeZone];
    
    if(![self.days containsObject:[NSNumber numberWithInt:day]]){
        return NO;
    }
    
    NSDate *start = [TLWeeklyTimeRange copyDateWithNSDate:date time:self.start timeZone:timeZone];
    NSDate *end = [TLWeeklyTimeRange copyDateWithNSDate:date time:self.end timeZone:timeZone];
        
    NSDateInterval *interval = [[NSDateInterval alloc] initWithStartDate:start endDate:end];
    
    return [interval containsDate:date];
}

- (nonnull NSString *)serialize {
    NSString *days = [self.days componentsJoinedByString:@"-"];
    return [NSString stringWithFormat:@"%@,%@,%@,%@", WEEKLY_TIME_RANGE_SERIALIZATION_PREFIX, days, [self.start toString], [self.end toString]];
}

+ (TLDayOfWeek)getDayOfWeekWithDate:(nonnull NSDate *)date timeZone:(nonnull NSTimeZone *)timeZone {
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    gregorian.timeZone = timeZone;
    int weekday = (int) [gregorian component:NSCalendarUnitWeekday fromDate:date];
    
    // NSCalendarUnitWeekdays starts with Sunday whereas TLDayOfWeek starts with Monday
    if(weekday == 1){
        return SUNDAY;
    } else {
        return weekday-1;
    }
}

+ (nonnull NSDate *)copyDateWithNSDate:(nonnull NSDate *)date time:(nonnull TLTime *)time timeZone:(nonnull NSTimeZone *)timeZone{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    gregorian.timeZone = timeZone;
    NSDateComponents *comps = [gregorian components:(NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay) fromDate:date ];

    comps.hour = time.hour;
    comps.minute = time.minute;
    comps.second = 0;
    
    return [gregorian dateFromComponents:comps];
}

- (BOOL) isEqual:(nullable id)object {
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLWeeklyTimeRange class]]) {
        return NO;
    }
    
    TLWeeklyTimeRange *timeRange = (TLWeeklyTimeRange *)object;
    
    return [self.days isEqualToArray:timeRange.days] && [self.start isEqual:timeRange.start] && [self.end isEqual:timeRange.end];
    
}

- (NSUInteger) hash {
    NSUInteger result = 17;
    for(NSNumber *day in self.days){
        result = 31 * result + day.hash;
    }
    result = 31 * result + self.start.hash;
    result = 31 * result + self.end.hash;
    return result;
}

- (NSComparisonResult)compare:(nonnull id<TLTimeRange>)timeRange {
    if([timeRange class] == [TLDateTimeRange class]){
        return NSOrderedDescending;
    }
    
    TLWeeklyTimeRange *o = (TLWeeklyTimeRange *)timeRange;

    NSComparisonResult res = [self.days[0] compare:o.days[0]];
    
    if(res == NSOrderedSame){
        res = [self.start compare:o.start];
        if(res == NSOrderedSame){
            res = [self.end compare:o.end];
        }
    }
    
    return res;
}

@end
