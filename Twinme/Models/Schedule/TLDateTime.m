/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLDateTime.h"

@implementation TLDateTime

- (nonnull instancetype)initWithDate:(nonnull TLDate *)date time:(nonnull TLTime *)time {
    self = [super init];
    if (self) {
        _date = date;
        _time = time;
    }
    return self;
}

- (nonnull instancetype)initWithDateTimeString:(nonnull NSString *)dateTime {
    NSArray<NSString *> *split = [dateTime componentsSeparatedByString:@"T"];
    
    if (split.count != 2){
        @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"Invalid dateTime" userInfo:@{@"dateTime": dateTime}];
    }
    
    self = [super init];
    if(self){
        _date = [[TLDate alloc] initWithDateString:split[0]];
        _time = [[TLTime alloc] initWithTimeString:split[1]];
    }
    return self;
}

- (nonnull NSString *)toString {
    NSString *d = [self.date toString];
    NSString *t = [self.time toString];
    
    return [NSString stringWithFormat:@"%@T%@", d, t];
}

- (nonnull NSString *)formatDateTime {
    NSString *d = [self.date formatDate];
    NSString *t = [self.time formatTime];
    
    return [NSString stringWithFormat:@"%@ %@", d, t];
}

- (nonnull NSDate *)toNSDateWithTimeZone:(nonnull NSTimeZone *)timeZone {
    NSDateComponents *components = [[NSDateComponents alloc] init];

    [components setTimeZone:timeZone];
    [components setDay:self.date.day];
    [components setMonth:self.date.month];
    [components setYear:self.date.year];
    [components setHour:self.time.hour];
    [components setMinute:self.time.minute];
    [components setSecond:0];

    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];

    return [gregorian dateFromComponents:components];
}

- (BOOL) isEqual:(nullable id)object {
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLDateTime class]]) {
        return NO;
    }
    
    TLDateTime *dateTime = (TLDateTime *)object;
    
    return [self.date isEqual:dateTime.date] && [self.time isEqual:dateTime.time];
}

- (NSUInteger) hash {
    NSUInteger result = 17;
    result = 31 * result + self.date.hash;
    result = 31 * result + self.time.hash;
    return result;
}

- (NSComparisonResult)compare:(nonnull TLDateTime *)dateTime {
    NSComparisonResult res = [self.date compare:dateTime.date];
    
    if(res == NSOrderedSame){
        res = [self.time compare:dateTime.time];
    }
    
    return res;
}


@end
