/*
 *  Copyright (c) 2019-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>

#import "TLUpdateStatsExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLContact.h"
#import "TLGroup.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.2
//

static const int UPDATE_CONTACT_STATS = 1 << 0;
static const int UPDATE_CONTACT_STATS_DONE = 1 << 1;
static const int UPDATE_GROUP_STATS = 1 << 2;
static const int UPDATE_GROUP_STATS_DONE = 1 << 3;

//
// Interface: TLUpdateStatsExecutor ()
//

@interface TLUpdateStatsExecutor ()

@property (nonatomic, readonly) BOOL updateScore;

@property (nonatomic, nullable) NSArray<id<TLRepositoryObject>> *contacts;
@property (nonatomic, nullable) NSArray<id<TLRepositoryObject>> *groups;

- (void)onTwinlifeOnline;

- (void)onOperation;

@end

//
// Implementation: TLUpdateStatsExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLUpdateStatsExecutor"

@implementation TLUpdateStatsExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId updateScore:(BOOL)updateScore {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld updateScore: %d", LOG_TAG, twinmeContext, requestId, updateScore);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId];
    if (self) {
        _updateScore = updateScore;
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & UPDATE_CONTACT_STATS) != 0 && (self.state & UPDATE_CONTACT_STATS_DONE) == 0) {
            self.state &= ~UPDATE_CONTACT_STATS;
        }
        if ((self.state & UPDATE_GROUP_STATS) != 0 && (self.state & UPDATE_GROUP_STATS_DONE) == 0) {
            self.state &= ~UPDATE_GROUP_STATS;
        }
    }
    [super onTwinlifeOnline];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Step 1: update the contact scores.
    //
    if ((self.state & UPDATE_CONTACT_STATS) == 0) {
        self.state |= UPDATE_CONTACT_STATS;

        [[self.twinmeContext getRepositoryService] updateStatsWithFactory:[TLContact FACTORY] updateScore:self.updateScore withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *objects) {
            self.state |= UPDATE_CONTACT_STATS_DONE;
            self.contacts = objects;
            [self onOperation];
        }];
    }
    if ((self.state & UPDATE_CONTACT_STATS_DONE) == 0) {
        return;
    }

    //
    // Step 2: update the group scores.
    //
    if ((self.state & UPDATE_GROUP_STATS) == 0) {
        self.state |= UPDATE_GROUP_STATS;

        [[self.twinmeContext getRepositoryService] updateStatsWithFactory:[TLGroup FACTORY] updateScore:self.updateScore withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *objects) {
            self.state |= UPDATE_GROUP_STATS_DONE;
            self.groups = objects;
            [self onOperation];
        }];
    }
    if ((self.state & UPDATE_GROUP_STATS_DONE) == 0) {
        return;
    }

    [self.twinmeContext onUpdateStatsWithRequestId:self.requestId contacts:self.contacts groups:self.groups];
    [self stop];
}

@end
