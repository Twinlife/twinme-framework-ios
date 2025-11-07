/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

//
// Interface TLDate
//

@interface TLDate : NSObject

/// This Date's year, e.g. 2023.
@property  (readonly) int year;

/// This Date's month, e.g. 1 for January.
@property (readonly) int month;

/// This Date's day of the month. The first day of the month is 1..
@property (readonly) int day;

- (nonnull instancetype)initWithYear:(int)year month:(int)month day:(int)day;

- (nonnull instancetype)initWithDateString:(nonnull NSString *)date;

- (nonnull NSString *)toString;

- (nonnull NSString *)formatDate;

- (NSComparisonResult)compare:(nonnull TLDate *)date;

@end
