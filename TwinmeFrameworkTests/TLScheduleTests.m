//
//  Tests.m
//  Tests
//
//  Created by Romain Kolb on 24/10/2023.
//  Copyright © 2023 Twinlife. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TLSchedule.h"
#import "TLCapabilities.h"

@interface TLScheduleTests : XCTestCase
@end

@implementation TLScheduleTests
NSTimeZone *UTC;

TLTime *EIGHT_AM;
TLTime *NINE_AM;
TLTime *TEN_AM;
TLTime *SIX_PM;
TLTime *EIGHT_PM;

TLDate *CHRISTMAS_2023;
TLDate *NYE_2024;

TLDateTime *MONDAY_NINE_AM;
TLDateTime *MONDAY_SIX_PM;
TLDateTime *SUNDAY_NINE_AM;

id<TLTimeRange> MONDAY_8AM_TO_10AM;
id<TLTimeRange> THURSDAY_6PM_TO_8PM;
id<TLTimeRange> CHRISTMAS_TO_NYE;
id<TLTimeRange> CHRISTMAS_2023_EIGHT_AM_TO_TEN_AM;

long NYE_2024_PLUS_ONE_DAY;
long NYE_2024_PLUS_ONE_HOUR;
long CHRISTMAS_2023_PLUS_ONE_DAY;
long CHRISTMAS_2023_PLUS_ONE_HOUR;
long CHRISTMAS_2023_SEVEN_AM;
long CHRISTMAS_2023_NINE_AM;
long CHRISTMAS_2023_ELEVEN_AM;

TLSchedule *weeklySchedule;
TLSchedule *dateTimeSchedule;

NSString * serializedWeeklySchedule = @"en=1;tz=UTC;tr=weekly,1,08:00,10:00;tr=weekly,4,18:00,20:00";
NSString * serializedDateTimeSchedule = @"en=1;tz=UTC;tr=dateTime,2023-12-25T08:00,2023-12-31T18:00";
NSString * serializedDisabledDateTimeSchedule = @"en=0;tz=UTC;tr=dateTime,2023-12-25T08:00,2023-12-31T18:00";

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    UTC = [[NSTimeZone alloc] initWithName:@"UTC"];
    
    EIGHT_AM = [self mkTime:@"08:00"];
    NINE_AM  = [self mkTime:@"09:00"];
    TEN_AM   = [self mkTime:@"10:00"];
    SIX_PM   = [self mkTime:@"18:00"];
    EIGHT_PM = [self mkTime:@"20:00"];
    
    CHRISTMAS_2023 = [self mkDate:@"2023-12-25"];
    NYE_2024 = [self mkDate:@"2023-12-31"];
    
    MONDAY_NINE_AM = [self mkDate:CHRISTMAS_2023 time:NINE_AM];
    MONDAY_SIX_PM = [self mkDate:CHRISTMAS_2023 time:SIX_PM];
    SUNDAY_NINE_AM = [self mkDate:NYE_2024 time:NINE_AM];
    
    MONDAY_8AM_TO_10AM = [[TLWeeklyTimeRange alloc] initWithDays:@[@(MONDAY)] start:EIGHT_AM end:TEN_AM];
    THURSDAY_6PM_TO_8PM = [[TLWeeklyTimeRange alloc] initWithDays:@[@(THURSDAY)] start:SIX_PM end:EIGHT_PM];
    CHRISTMAS_TO_NYE = [[TLDateTimeRange alloc] initWithStart:[self mkDate:CHRISTMAS_2023 time:EIGHT_AM] end:[self mkDate:NYE_2024 time:SIX_PM]];
    CHRISTMAS_2023_EIGHT_AM_TO_TEN_AM = [[TLDateTimeRange alloc] initWithStart:[self mkDate:CHRISTMAS_2023 time:EIGHT_AM] end:[self mkDate:CHRISTMAS_2023 time:TEN_AM]];

    weeklySchedule = [[TLSchedule alloc] initWithPrivate:false timeZone:UTC timeRanges:@[THURSDAY_6PM_TO_8PM, MONDAY_8AM_TO_10AM]];
    
    dateTimeSchedule = [[TLSchedule alloc] initWithPrivate:false timeZone:UTC timeRanges:@[CHRISTMAS_TO_NYE]];
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH:mmZ"];
    
    NYE_2024_PLUS_ONE_DAY = [dateFormat dateFromString:@"2024-01-01T18:00+0000"].timeIntervalSince1970;
    NYE_2024_PLUS_ONE_HOUR = [dateFormat dateFromString:@"2023-12-31T19:00+0000"].timeIntervalSince1970;
    CHRISTMAS_2023_PLUS_ONE_DAY = [dateFormat dateFromString:@"2023-12-26T08:00+0000"].timeIntervalSince1970;
    CHRISTMAS_2023_PLUS_ONE_HOUR = [dateFormat dateFromString:@"2023-12-25T09:00+0000"].timeIntervalSince1970;
    CHRISTMAS_2023_SEVEN_AM = [dateFormat dateFromString:@"2023-12-25T07:00+0000"].timeIntervalSince1970;
    CHRISTMAS_2023_NINE_AM = [dateFormat dateFromString:@"2023-12-25T09:00+0000"].timeIntervalSince1970;
    CHRISTMAS_2023_ELEVEN_AM = [dateFormat dateFromString:@"2023-12-25T11:00+0000"].timeIntervalSince1970;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testWeeklyToCapabilities {
    XCTAssertEqualObjects(serializedWeeklySchedule, [weeklySchedule toCapability]);
}

- (void)testWeeklyInCapabilitiesObject {
    TLCapabilities *caps = [[TLCapabilities alloc] init];
    caps.schedule = weeklySchedule;
    
    TLSchedule *capSchedule = caps.schedule;
    
    [self assertScheduleWithExpected:weeklySchedule actual:capSchedule];
}

- (void)testWeeklyOfCapabilities {
    TLSchedule *parsedSchedule = [TLSchedule ofCapabilityWithCapabilityString:serializedWeeklySchedule];
    
    [self assertScheduleWithExpected:weeklySchedule actual:parsedSchedule];
}

- (void)testDateTimeToCapabilities {
    XCTAssertEqualObjects(serializedDateTimeSchedule, [dateTimeSchedule toCapability]);
}

- (void)testDateTimeInCapabilitiesObject {
    TLCapabilities *caps = [[TLCapabilities alloc] init];
    caps.schedule = dateTimeSchedule;
    
    TLSchedule *capSchedule = caps.schedule;
    
    [self assertScheduleWithExpected:dateTimeSchedule actual:capSchedule];
}

- (void)testDateTimeOfCapabilities {
    TLSchedule *parsedSchedule = [TLSchedule ofCapabilityWithCapabilityString:serializedDateTimeSchedule];
    
    [self assertScheduleWithExpected:dateTimeSchedule actual:parsedSchedule];
}

- (void)testDisabledDateTimeToCapabilities {
    TLSchedule *parsedSchedule = [TLSchedule ofCapabilityWithCapabilityString:serializedDateTimeSchedule];
    parsedSchedule.enabled = NO;
    XCTAssertEqualObjects(serializedDisabledDateTimeSchedule, [parsedSchedule toCapability]);
}

- (void)testDateTimeIsInRange {
    XCTAssertTrue([CHRISTMAS_TO_NYE isTimestampInRangeWithTimeStamp:CHRISTMAS_2023_PLUS_ONE_DAY timeZone:UTC]);
    XCTAssertTrue([CHRISTMAS_TO_NYE isTimestampInRangeWithTimeStamp:CHRISTMAS_2023_PLUS_ONE_HOUR timeZone:UTC]);
    XCTAssertTrue([CHRISTMAS_2023_EIGHT_AM_TO_TEN_AM isTimestampInRangeWithTimeStamp:CHRISTMAS_2023_NINE_AM timeZone:UTC]);
}

- (void)testDateTimeIsNotInRange {
    XCTAssertFalse([CHRISTMAS_TO_NYE isTimestampInRangeWithTimeStamp:NYE_2024_PLUS_ONE_DAY timeZone:UTC]);
    XCTAssertFalse([CHRISTMAS_2023_EIGHT_AM_TO_TEN_AM isTimestampInRangeWithTimeStamp:CHRISTMAS_2023_SEVEN_AM timeZone:UTC]);
    XCTAssertFalse([CHRISTMAS_2023_EIGHT_AM_TO_TEN_AM isTimestampInRangeWithTimeStamp:CHRISTMAS_2023_ELEVEN_AM timeZone:UTC]);
}

- (void)testWeeklyIsInRange {
    XCTAssertTrue([MONDAY_8AM_TO_10AM isTimestampInRangeWithTimeStamp:CHRISTMAS_2023_NINE_AM timeZone:UTC]);
}

#pragma utilities

- (TLTime *) mkTime:(NSString *)time{
    return [[TLTime alloc] initWithTimeString:time];
}

- (TLDate *) mkDate:(NSString *)date{
    return [[TLDate alloc] initWithDateString:date];
}

- (TLDateTime *) mkDate:(TLDate *)date time:(TLTime *)time {
    return [[TLDateTime alloc] initWithDate:date time:time];
}

- (void) assertScheduleWithExpected:(TLSchedule *)expected actual:(TLSchedule *)actual {
    XCTAssertNotNil(actual);
    
    XCTAssertEqual(expected.enabled, actual.enabled);
    
    XCTAssertEqualObjects(expected.timeZone, actual.timeZone);
    XCTAssertEqual(expected.timeRanges.count, actual.timeRanges.count);
    
    for(int i=0; i<expected.timeRanges.count; i++){
        XCTAssertEqualObjects(expected.timeRanges[i], actual.timeRanges[i]);
    }
}

@end
