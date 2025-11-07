/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#include "TLDate.h"
#include "TLTime.h"

//
// Interface TLDate
//

@interface TLDateTime : NSObject

@property (readonly, nonnull) TLDate *date;

@property (readonly, nonnull) TLTime *time;

- (nonnull instancetype)initWithDate:(nonnull TLDate *)date time:(nonnull TLTime *)time;

- (nonnull instancetype)initWithDateTimeString:(nonnull NSString *)dateTime;

- (nonnull NSString *)toString;

- (nonnull NSString *)formatDateTime;

- (nonnull NSDate *)toNSDateWithTimeZone:(nonnull NSTimeZone *)timeZone;

- (NSComparisonResult)compare:(nonnull TLDateTime *)dateTime;

@end
