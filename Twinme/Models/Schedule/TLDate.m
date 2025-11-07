/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLDate.h"

@implementation TLDate

- (nonnull instancetype)initWithYear:(int)year month:(int)month day:(int)day {
    self = [super init];
    if (self) {
        _year = year;
        _month = month;
        _day = day;
    }
    return self;
}

- (nonnull instancetype)initWithDateString:(nonnull NSString *)date{
    NSArray<NSString *> *split = [date componentsSeparatedByString:@"-"];
    
    if (split.count != 3){
        @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"Invalid date" userInfo:@{@"date": date}];
    }
    
    self = [super init];
    if(self){
        _year = split[0].intValue;
        _month = split[1].intValue;
        _day = split[2].intValue;
    }
    return self;
}

- (nonnull NSString *)toString {
        
    NSString *yy = [NSString stringWithFormat:@"%04d", self.year];
    NSString *mm = [NSString stringWithFormat:@"%02d", self.month];
    NSString *dd = [NSString stringWithFormat:@"%02d", self.day];
    
    return [NSString stringWithFormat:@"%@-%@-%@", yy, mm, dd];
}

- (nonnull NSString *)formatDate {
    
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    dateComponents.day = self.day;
    dateComponents.month = self.month;
    dateComponents.year = self.year;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [calendar dateFromComponents:dateComponents];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    dateFormatter.locale = [NSLocale currentLocale];
    [dateFormatter setDateFormat:@"dd MMM yyyy"];
    
    return [dateFormatter stringFromDate:date];
}

- (BOOL) isEqual:(nullable id)object {
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLDate class]]) {
        return NO;
    }
    
    TLDate *date = (TLDate *)object;
    
    return self.year == date.year && self.month == date.month && self.day == date.day;
}

- (NSUInteger) hash {
    NSUInteger result = 17;
    result = 31 * result + self.year;
    result = 31 * result + self.month;
    result = 31 * result + self.day;
    return result;
}


- (NSComparisonResult)compare:(nonnull TLDate *)date {
    NSComparisonResult res = [@(self.year) compare:@(date.year)];
    
    if(res == NSOrderedSame){
        res = [@(self.month) compare:@(date.month)];
        if(res == NSOrderedSame){
            res = [@(self.day) compare:@(date.day)];
        }
    }
    
    return res;
}

@end
