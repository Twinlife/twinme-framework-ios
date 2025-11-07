/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLLocationReport
//

@class TLTwinmeContext;
@class TLGeolocationDescriptor;

@interface TLLocationReport : NSObject

+ (void)recordGeolocationWithDescriptor:(nonnull TLGeolocationDescriptor *)descriptor;

+ (nullable NSString *)report;

@end

//
// Interface: TLReportStatsExecutor
//

@interface TLReportStatsExecutor : TLAbstractConnectedTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId;

- (NSTimeInterval) nextDelay;

@end
