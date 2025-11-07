/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>

#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAccountMigrationService.h>

#import "TLGetAccountMigrationExecutor.h"
#import "TLAccountMigration.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_OBJECT = 1;
static const int GET_OBJECT_DONE = 1 << 1;
static const int REFRESH_PEER_TWINCODE_OUTBOUND = 1 << 2;
static const int REFRESH_PEER_TWINCODE_OUTBOUND_DONE = 1 << 3;

//
// Interface: TLGetAccountMigrationExecutor ()
//

@interface TLGetAccountMigrationExecutor ()

@property (nonatomic, readonly, nonnull) NSUUID *accountMigrationId;
@property (nonatomic, readonly, nonnull) void (^onGetAccountMigration) (TLBaseServiceErrorCode errorCode, TLAccountMigration *accountMigration);

@property (nonatomic, nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic) BOOL toBeDeleted;
@property (nonatomic, nullable) TLAccountMigration *accountMigration;

@end

//
// Implementation: TLGetAccountMigrationExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLGetAccountMigrationExecutor"

@implementation TLGetAccountMigrationExecutor



- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext deviceMigrationId:(nonnull NSUUID *)deviceMigrationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode, TLAccountMigration * _Nullable __strong))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ deviceMigrationId: %@", LOG_TAG, twinmeContext, deviceMigrationId);

    self = [super initWithTwinmeContext:twinmeContext requestId:0];

    if (self) {
        _accountMigrationId = deviceMigrationId;
        _onGetAccountMigration = block;
    }
    
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & REFRESH_PEER_TWINCODE_OUTBOUND) != 0 && (self.state & REFRESH_PEER_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~REFRESH_PEER_TWINCODE_OUTBOUND;
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
    // Step 1: get the object from the repository.
    //
    if ((self.state & GET_OBJECT) == 0) {
        self.state |= GET_OBJECT;
        
        DDLogDebug(@"%@ RepositoryService.getObject: obbjectId:%@ schemaId:%@", LOG_TAG, self.accountMigrationId, [TLAccountMigration SCHEMA_ID]);
        
        [self.twinmeContext.getRepositoryService getObjectWithFactory:[TLAccountMigration FACTORY] objectId:self.accountMigrationId withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject>  _Nullable object) {
            [self onGetObjectWithErrorCode:errorCode accountMigration:(TLAccountMigration *)object];
        }];
        return;
    }
    
    if ((self.state & GET_OBJECT_DONE) ==0) {
        return;
    }
    
    //
    // Step 2: refresh the peer twincode.
    //
    if (self.peerTwincodeOutbound) {
        if ((self.state & REFRESH_PEER_TWINCODE_OUTBOUND) == 0) {
            self.state |= REFRESH_PEER_TWINCODE_OUTBOUND;
            
            [self.twinmeContext.getTwincodeOutboundService refreshTwincodeWithTwincode:self.peerTwincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, NSMutableArray<TLAttributeNameValue *> * _Nullable previousAttributes) {
                [self onRefreshTwincodeOutbound:previousAttributes errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & REFRESH_PEER_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 3: if the device migration was interrupted and must be canceled.
    if (self.toBeDeleted) {
        DDLogVerbose(@"%@ TwinmeContext.deleteObject: objectId:%@", LOG_TAG, self.accountMigrationId);
        [self.twinmeContext.getAccountMigrationService cancelMigrationWithDeviceMigrationId:self.accountMigrationId];
        if (self.accountMigration) {
            [self.twinmeContext deleteAccountMigrationWithAccountMigration:self.accountMigration withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable uuid) {}];
        }

        self.onGetAccountMigration(TLBaseServiceErrorCodeItemNotFound, nil);
        [self stop];
        return;
    }
    
    //
    // Last Step
    //
    self.onGetAccountMigration(TLBaseServiceErrorCodeSuccess, self.accountMigration);
   
    [self stop];
}

- (void)onGetObjectWithErrorCode:(TLBaseServiceErrorCode)errorCode accountMigration:(nullable TLAccountMigration *)accountMigration {
    DDLogVerbose(@"%@ onGetObjectWithErrorCode:%d accountMigration:%@", LOG_TAG, errorCode, accountMigration);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !accountMigration) {
        self.onGetAccountMigration(errorCode, nil);
        [self stop];
        return;
    }

    self.state |= GET_OBJECT_DONE;
    self.accountMigration = accountMigration;
    self.peerTwincodeOutbound = accountMigration.peerTwincodeOutbound;
    [self onOperation];
}

- (void)onRefreshTwincodeOutbound:(nullable NSMutableArray<TLAttributeNameValue *> *)updatedAttributes errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onRefreshTwincodeOutbound: %@ errorCode: %d", LOG_TAG, updatedAttributes, errorCode);

    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    self.state |= REFRESH_PEER_TWINCODE_OUTBOUND_DONE;
    if (errorCode != TLBaseServiceErrorCodeSuccess) {
        // Peer twincode is invalid, we must delete this account migration.
        self.toBeDeleted = YES;
    }
    
    [self onOperation];
}

@end
