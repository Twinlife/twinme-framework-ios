/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

//
// Interface TLTime
//

@interface TLTime : NSObject

/// This Time's hour, 24-hour based, e.g. 22 for 10:00PM.
@property (readonly) int hour;

/// This Time's minute.
@property (readonly) int minute;

- (nonnull instancetype)initWithHour:(int)hour minute:(int)minute;

- (nonnull instancetype)initWithTimeString:(nonnull NSString *)time;

- (nonnull NSString *)toString;

- (nonnull NSString *)formatTime;

- (NSComparisonResult)compare:(nonnull TLTime *)time;

@end
