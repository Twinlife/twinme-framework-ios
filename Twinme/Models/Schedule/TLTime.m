/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLTime.h"

@implementation TLTime

- (nonnull instancetype)initWithHour:(int)hour minute:(int)minute{
    self = [super init];
    if (self) {
        _hour = hour;
        _minute = minute;
    }
    return self;
}

- (nonnull instancetype)initWithTimeString:(nonnull NSString *)time{
    NSArray<NSString *> *split = [time componentsSeparatedByString:@":"];
    
    if (split.count != 2){
        @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"Invalid time" userInfo:@{@"time": time}];
    }
    
    self = [super init];
    if(self){
        _hour = split[0].intValue;
        _minute = split[1].intValue;
    }
    return self;
}

- (nonnull NSString *)toString {
    NSString *hh = [NSString stringWithFormat:@"%02d", self.hour];
    NSString *mm = [NSString stringWithFormat:@"%02d", self.minute];
    
    return [NSString stringWithFormat:@"%@:%@", hh, mm];
}

- (nonnull NSString *)formatTime {
    
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    dateComponents.hour = self.hour;
    dateComponents.minute = self.minute;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [calendar dateFromComponents:dateComponents];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    dateFormatter.locale = [NSLocale currentLocale];
    [dateFormatter setDateFormat:@"HH:mm"];
    
    return [dateFormatter stringFromDate:date];
}

- (BOOL) isEqual:(nullable id)object {
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLTime class]]) {
        return NO;
    }
    
    TLTime *time = (TLTime *)object;
    
    return self.hour == time.hour && self.minute == time.minute;
}

- (NSUInteger) hash {
    NSUInteger result = 17;
    result = 31 * result + self.hour;
    result = 31 * result + self.minute;
    return result;
}

- (NSComparisonResult)compare:(nonnull TLTime *)time {
    NSComparisonResult res = [@(self.hour) compare:@(time.hour)];
    
    if(res == NSOrderedSame){
        res = [@(self.minute) compare:@(time.minute)];
    }
    
    return res;
}

@end
