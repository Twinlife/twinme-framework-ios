/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLManagementService.h>
#import <Twinlife/TLDeviceInfo.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLConfigIdentifier.h>

#import "TLReportStatsExecutor.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLTwinmeContextImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.3
//

static const int REPORT_CONTACT_STATS = 1 << 0;
static const int REPORT_CONTACT_STATS_DONE = 1 << 1;
static const int REPORT_GROUP_STATS = 1 << 2;
static const int REPORT_GROUP_STATS_DONE = 1 << 3;
static const int REPORT_SEND = 1 << 4;
static const int REPORT_SEND_DONE = 1 << 6;

#define REPOSITORY_REPORT @"repositoryReport"
#define EVENT_ID_REPORT_STATS @"twinme::stats"
#define LAST_REPORT_DATE @"lastReportDate"
#define NEW_REPORT_DATE @"currentReportDate"
#define DEVICE_REPORT @"iosDeviceReport"
#define SERVICE_REPORT @"serviceReport"
#define LOCATION_REPORT @"locationReport"
#define REPOSITORY_REPORT_VERSION @"4:"
#define DEVICE_REPORT_VERSION @"1:"
#define SERVICE_REPORT_VERSION @"2:"
#define LOCATION_REPORT_VERSION @"1:"

#define REPORT_STAT_PREFERENCES @"TwinmeStats"
#define MIN_REPORT_DELAY 24 * 3600 * 1000 // 24 h in ms

#define LOCATION_TIMESTAMP_PREFERENCE @"locationTimestamp"
#define LONGITUDE_PREFERENCE @"longitude"
#define LATITUDE_PREFERENCE @"latitude"
#define ALTITUDE_PREFERENCE @"altitude"

//
// Implementation: TLLocationReport
//

#undef LOG_TAG
#define LOG_TAG @"TLLocationReport"

@implementation TLLocationReport

+ (void)recordGeolocationWithDescriptor:(nonnull TLGeolocationDescriptor *)descriptor {

    if ([TLTwinmeContext ENABLE_REPORT_LOCATION]) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:[[NSNumber alloc] initWithLongLong:descriptor.createdTimestamp] forKey:LOCATION_TIMESTAMP_PREFERENCE];
        [userDefaults setObject:[[NSNumber alloc] initWithDouble:descriptor.longitude] forKey:LONGITUDE_PREFERENCE];
        [userDefaults setObject:[[NSNumber alloc] initWithDouble:descriptor.latitude] forKey:LATITUDE_PREFERENCE];
        [userDefaults setObject:[[NSNumber alloc] initWithDouble:descriptor.altitude] forKey:ALTITUDE_PREFERENCE];
        [userDefaults synchronize];
    }
}

+ (nullable NSString *)report {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    id object = [userDefaults objectForKey:LOCATION_TIMESTAMP_PREFERENCE];
    if (!object) {
        return nil;
    }
    NSMutableString *locationReport = [NSMutableString stringWithCapacity:1024];
    [locationReport appendFormat:@"%lld:", [object longLongValue]];
    object = [userDefaults objectForKey:LONGITUDE_PREFERENCE];
    if (!object) {
        return nil;
    }
    [locationReport appendFormat:@"%f:", [object doubleValue]];

    object = [userDefaults objectForKey:LATITUDE_PREFERENCE];
    if (!object) {
        return nil;
    }
    [locationReport appendFormat:@"%f:", [object doubleValue]];

    object = [userDefaults objectForKey:ALTITUDE_PREFERENCE];
    if (!object) {
        return nil;
    }
    [locationReport appendFormat:@"%f", [object doubleValue]];
    return locationReport;
}

@end

//
// Interface(): TLReportStatsExecutor
//

@interface TLReportStatsExecutor()

@property (nonatomic) int64_t lastReportDate;
@property (nonatomic) int64_t nextReportDate;
@property (nonatomic) int64_t newReportDate;
@property (nonatomic, readonly, nonnull) NSMutableString *report;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onReportContactStats:(nonnull TLStatReport *)stats;

- (void)onReportGroupStats:(nonnull TLStatReport *)stats;

@end

//
// Implementation: TLReportStatsExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLReportStatsExecutor"

@implementation TLReportStatsExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld", LOG_TAG, twinmeContext, requestId);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId];
    
    if (self) {
        _report = [NSMutableString stringWithCapacity:1024];
    }
    return self;
}

- (NSTimeInterval) nextDelay {
    DDLogVerbose(@"%@ nextDelay", LOG_TAG);

    self.newReportDate = [[NSDate date] timeIntervalSince1970] * 1000;
    self.lastReportDate = [self.twinmeContext.lastReportDate int64Value];

    self.nextReportDate = self.lastReportDate + MIN_REPORT_DELAY;
    return (NSTimeInterval) (self.nextReportDate - self.newReportDate) / 1000.0;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    self.state = 0;
    [super onTwinlifeOnline];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Step 1: check if a report is needed.
    //
    if (self.newReportDate == 0) {
        long delay = [self nextDelay];
        if (delay > 0) {

            [self.twinmeContext onReportStatsWithRequestId:self.requestId delay:delay];

            [self stop];
            return;
        }
        [self.report appendString:REPOSITORY_REPORT_VERSION];
    }
    
    //
    // Step 2: report stats on contacts.
    //
    
    if ((self.state & REPORT_CONTACT_STATS) == 0) {
        self.state |= REPORT_CONTACT_STATS;

        DDLogVerbose(@"%@ reportStatsWithSchemaId: %@", LOG_TAG, [TLContact SCHEMA_ID]);
        TLStatReport *stats = [[self.twinmeContext getRepositoryService] reportStatsWithSchemaId:[TLContact SCHEMA_ID]];
        [self onReportContactStats:stats];
    }

    //
    // Step 3: report stats on groups.
    //
    
    if ((self.state & REPORT_GROUP_STATS) == 0) {
        self.state |= REPORT_GROUP_STATS;
        
        DDLogVerbose(@"%@ reportStatsWithSchemaId: %@", LOG_TAG, [TLGroup SCHEMA_ID]);
        TLStatReport *stats = [[self.twinmeContext getRepositoryService] reportStatsWithSchemaId:[TLGroup SCHEMA_ID]];
        [self onReportGroupStats:stats];
    }

    //
    // Step 4: send the report
    //
    if ((self.state & REPORT_SEND) == 0) {
        self.state |= REPORT_SEND;
        NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithCapacity:5];
        
        [attributes setObject:[NSString stringWithFormat:@"%lld", self.lastReportDate] forKey:LAST_REPORT_DATE];
        [attributes setObject:[NSString stringWithFormat:@"%lld", self.newReportDate] forKey:NEW_REPORT_DATE];
        [attributes setObject:self.report forKey:REPOSITORY_REPORT];

        TLDeviceInfo *deviceInfo = [self.twinmeContext.twinlife getDeviceInfo];
        NSMutableString *deviceReport = [NSMutableString stringWithCapacity:1024];
        [deviceReport appendString:DEVICE_REPORT_VERSION];
        [deviceReport appendFormat:@":%d:%d:%.1f", deviceInfo.isLowPowerModeEnabled, deviceInfo.charging, deviceInfo.batteryLevel];
        [deviceReport appendFormat:@":%lld:%lld:%ld", deviceInfo.backgroundTime, deviceInfo.foregroundTime, deviceInfo.pushCount];
        [attributes setObject:deviceReport forKey:DEVICE_REPORT];

        NSDictionary<NSString *, TLServiceStats *> *serviceStats = [self.twinmeContext getServiceStats];
        NSMutableString *serviceReport = [NSMutableString stringWithCapacity:1024];
        [serviceReport appendString:SERVICE_REPORT_VERSION];
        for (id service in serviceStats) {
            NSString *name = (NSString *) service;
            TLServiceStats *stat = serviceStats[name];
            if (stat && (stat.sendPacketCount > 0 || stat.sendErrorCount > 0 || stat.sendDisconnectedCount > 0 || stat.sendTimeoutCount > 0)) {
                [serviceReport appendFormat:@":%@=%d:%d:%d:%d", name, stat.sendPacketCount, stat.sendDisconnectedCount, stat.sendErrorCount, stat.sendTimeoutCount];
            }
        }
        [attributes setObject:serviceReport forKey:SERVICE_REPORT];

        // Send the last known location if the report is enabled and we know the position.
        if ([TLTwinmeContext ENABLE_REPORT_LOCATION]) {
            NSString *report = [TLLocationReport report];
            if (report) {
                NSMutableString *locationReport = [NSMutableString stringWithCapacity:1024];
                [locationReport appendString:LOCATION_REPORT_VERSION];
                [locationReport appendString:report];

                [attributes setObject:locationReport forKey:LOCATION_REPORT];
            }
        }

        [[self.twinmeContext.twinlife getManagementService] logEventWithEventId:EVENT_ID_REPORT_STATS attributes:attributes flush:YES];

        // Last Step: checkpoint for the next report.
        [[self.twinmeContext getRepositoryService] checkpointStats];
        self.twinmeContext.lastReportDate.int64Value = self.newReportDate;
        self.state |= REPORT_SEND_DONE;
    }
    
    //
    // Last Step
    //
    long delayMs = self.newReportDate + MIN_REPORT_DELAY - [[NSDate date] timeIntervalSince1970] * 1000;
    [self.twinmeContext onReportStatsWithRequestId:self.requestId delay:(NSTimeInterval)delayMs / 1000.0];
    [self stop];
}

// Tables that defines the values and their order to put in the report.
static const TLRepositoryServiceStatType CONTACT_SEND_REPORT[] = {
    TLRepositoryServiceStatTypeNbMessageSent,
    TLRepositoryServiceStatTypeNbImageSent,
    TLRepositoryServiceStatTypeNbVideoSent,
    TLRepositoryServiceStatTypeNbFileSent,
    TLRepositoryServiceStatTypeNbAudioSent,
    TLRepositoryServiceStatTypeNbGeolocationSent,
    TLRepositoryServiceStatTypeNbTwincodeSent
};
static const int CONTACT_SEND_REPORT_COUNT = sizeof(CONTACT_SEND_REPORT) / sizeof(CONTACT_SEND_REPORT[0]);

static const TLRepositoryServiceStatType CONTACT_RECEIVE_REPORT[] = {
    TLRepositoryServiceStatTypeNbMessageReceived,
    TLRepositoryServiceStatTypeNbImageReceived,
    TLRepositoryServiceStatTypeNbVideoReceived,
    TLRepositoryServiceStatTypeNbFileReceived,
    TLRepositoryServiceStatTypeNbAudioReceived,
    TLRepositoryServiceStatTypeNbGeolocationReceived,
    TLRepositoryServiceStatTypeNbTwincodeReceived
};
static const int CONTACT_RECEIVE_REPORT_COUNT = sizeof(CONTACT_RECEIVE_REPORT) / sizeof(CONTACT_RECEIVE_REPORT[0]);

static const TLRepositoryServiceStatType CONTACT_SEND_AUDIO_REPORT[] = {
    TLRepositoryServiceStatTypeNbAudioCallSent
};
static const int CONTACT_SEND_AUDIO_REPORT_COUNT = sizeof(CONTACT_SEND_AUDIO_REPORT) / sizeof(CONTACT_SEND_AUDIO_REPORT[0]);

static const TLRepositoryServiceStatType CONTACT_RECEIVE_AUDIO_REPORT[] = {
    TLRepositoryServiceStatTypeNbAudioCallReceived,
    TLRepositoryServiceStatTypeNbAudioCallMissed
};
static const int CONTACT_RECEIVE_AUDIO_REPORT_COUNT = sizeof(CONTACT_RECEIVE_AUDIO_REPORT) / sizeof(CONTACT_RECEIVE_AUDIO_REPORT[0]);

static const TLRepositoryServiceStatType CONTACT_SEND_VIDEO_REPORT[] = {
    TLRepositoryServiceStatTypeNbVideoCallSent
};
static const int CONTACT_SEND_VIDEO_REPORT_COUNT = sizeof(CONTACT_SEND_VIDEO_REPORT) / sizeof(CONTACT_SEND_VIDEO_REPORT[0]);

static const TLRepositoryServiceStatType CONTACT_RECEIVE_VIDEO_REPORT[] = {
    TLRepositoryServiceStatTypeNbVideoCallReceived,
    TLRepositoryServiceStatTypeNbVideoCallMissed
};
static const int CONTACT_RECEIVE_VIDEO_REPORT_COUNT = sizeof(CONTACT_RECEIVE_VIDEO_REPORT) / sizeof(CONTACT_RECEIVE_VIDEO_REPORT[0]);

static const TLRepositoryServiceStatType GROUP_SEND_REPORT[] = {
    TLRepositoryServiceStatTypeNbMessageSent,
    TLRepositoryServiceStatTypeNbImageSent,
    TLRepositoryServiceStatTypeNbVideoSent,
    TLRepositoryServiceStatTypeNbFileSent,
    TLRepositoryServiceStatTypeNbAudioSent,
    TLRepositoryServiceStatTypeNbGeolocationSent,
    TLRepositoryServiceStatTypeNbTwincodeSent
};
static const int GROUP_SEND_REPORT_COUNT = sizeof(GROUP_SEND_REPORT) / sizeof(GROUP_SEND_REPORT[0]);

static const TLRepositoryServiceStatType GROUP_RECEIVE_REPORT[] = {
    TLRepositoryServiceStatTypeNbMessageReceived,
    TLRepositoryServiceStatTypeNbImageReceived,
    TLRepositoryServiceStatTypeNbVideoReceived,
    TLRepositoryServiceStatTypeNbFileReceived,
    TLRepositoryServiceStatTypeNbAudioReceived,
    TLRepositoryServiceStatTypeNbGeolocationReceived,
    TLRepositoryServiceStatTypeNbTwincodeReceived
};
static const int GROUP_RECEIVE_REPORT_COUNT = sizeof(GROUP_RECEIVE_REPORT) / sizeof(GROUP_RECEIVE_REPORT[0]);

- (void)reportStatWithName:(nonnull NSString*)name stat:(TLObjectStatReport *)stat report:(const TLRepositoryServiceStatType[])report reportCount:(int)reportCount {
    DDLogVerbose(@"%@ reportStatWithName %@ stat: %@ reportCount: %d", LOG_TAG, name, stat, reportCount);

    BOOL empty = YES;
    for (int i = 0; i < reportCount; i++) {
        if (stat.statCounters[report[i]] > 0) {
            empty = NO;
            break;
        }
    }

    // Report the stats when there are some values.
    if (!empty) {
        [self.report appendString:name];
        for (int i = 0; i < reportCount; i++) {
            [self.report appendFormat:@":%d", stat.statCounters[report[i]]];
        }
    }
}

- (void)onReportContactStats:(nonnull TLStatReport *)stats {
    DDLogVerbose(@"%@ onReportContactStats %@ ", LOG_TAG, stats);

    self.state |= REPORT_CONTACT_STATS_DONE;

    [self.report appendFormat:@":contacts:%d:%d:%d", stats.objectCount, stats.certifiedCount, stats.invitationCodeCount];
    if (stats.stats.count == 0) {
        [self.report appendString:@":"];
    } else {
        for (TLObjectStatReport *stat in stats.stats) {
            [self reportStatWithName:@":csend" stat:stat report:CONTACT_SEND_REPORT reportCount:CONTACT_SEND_REPORT_COUNT];
            [self reportStatWithName:@":crecv" stat:stat report:CONTACT_RECEIVE_REPORT reportCount:CONTACT_RECEIVE_REPORT_COUNT];
            [self reportStatWithName:@":asend" stat:stat report:CONTACT_SEND_AUDIO_REPORT reportCount:CONTACT_SEND_AUDIO_REPORT_COUNT];
            [self reportStatWithName:@":arecv" stat:stat report:CONTACT_RECEIVE_AUDIO_REPORT reportCount:CONTACT_RECEIVE_AUDIO_REPORT_COUNT];
            [self reportStatWithName:@":vsend" stat:stat report:CONTACT_SEND_VIDEO_REPORT reportCount:CONTACT_SEND_VIDEO_REPORT_COUNT];
            [self reportStatWithName:@":vrecv" stat:stat report:CONTACT_RECEIVE_VIDEO_REPORT reportCount:CONTACT_RECEIVE_VIDEO_REPORT_COUNT];
            [self.report appendString:@";"];
        }
    }
}

- (void)onReportGroupStats:(nonnull TLStatReport *)stats {
    DDLogVerbose(@"%@ onReportGroupStats %@", LOG_TAG, stats);

    self.state |= REPORT_GROUP_STATS_DONE;

    [self.report appendFormat:@":groups:%d", stats.objectCount + stats.certifiedCount + stats.invitationCodeCount];
    if (stats.stats.count == 0) {
        [self.report appendString:@":"];
    } else {
        for (TLObjectStatReport *stat in stats.stats) {
            [self reportStatWithName:@":gsend" stat:stat report:GROUP_SEND_REPORT reportCount:GROUP_SEND_REPORT_COUNT];
            [self reportStatWithName:@":grecv" stat:stat report:GROUP_RECEIVE_REPORT reportCount:GROUP_RECEIVE_REPORT_COUNT];
            [self.report appendString:@";"];
        }
    }
}

@end
