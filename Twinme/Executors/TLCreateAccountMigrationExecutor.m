/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLCreateAccountMigrationExecutor.h"
#import "TLAccountMigration.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLCallReceiver.h"
#import "TLPairProtocol.h"
#import "TLTwinmeAttributes.h"
#import <Twinlife/TLBaseService.h>
#import <Twinlife/TLAccountMigrationService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_OBJECT_IDS = 1 << 0;
static const int GET_OBJECT_IDS_DONE = 1 << 1;
static const int CREATE_TWINCODE = 1 << 2;
static const int CREATE_TWINCODE_DONE = 1 << 3;
static const int CREATE_OBJECT = 1 << 4;
static const int CREATE_OBJECT_DONE = 1 << 5;
static const int UPDATE_TWINCODE = 1 << 6;
static const int UPDATE_TWINCODE_DONE = 1 << 7;


@interface TLCreateAccountMigrationExecutor ()

@property (nonatomic, readonly, nonnull) void (^onCreateAccountMigration)(TLBaseServiceErrorCode, TLAccountMigration * _Nullable __strong);

@property (nonatomic, nullable) TLTwincodeFactory *twincodeFactory;

@property (nonatomic, nullable) TLAccountMigration *accountMigration;

@property BOOL hasRelations;

@end

#undef LOG_TAG
#define LOG_TAG @"TLCreateAccountMigrationExecutor"

@implementation TLCreateAccountMigrationExecutor

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext withBlock:(nonnull void (^)(TLBaseServiceErrorCode, TLAccountMigration * _Nullable __strong))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:TLBaseService.DEFAULT_REQUEST_ID];
    
    if (self) {
        _onCreateAccountMigration = block;
        _hasRelations = NO;
    }
    
    return self;
}

- (void) onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    if (self.restarted) {
        if ((self.state & CREATE_TWINCODE) != 0 && (self.state & CREATE_TWINCODE_DONE) != 0) {
            self.state &= ~CREATE_TWINCODE;
        }
        
        if ((self.state & UPDATE_TWINCODE) != 0 && (self.state & UPDATE_TWINCODE_DONE) != 0) {
            self.state &= ~UPDATE_TWINCODE;
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
    // Step 1: get the list of account migration objects to remove them.
    //
    
    if ((self.state & GET_OBJECT_IDS) == 0) {
        self.state |= GET_OBJECT_IDS;
        
        TLRepositoryService *repositoryService = [self.twinmeContext getRepositoryService];
        self.hasRelations = [repositoryService hasObjectsWithSchemaId:[TLContact SCHEMA_ID]];
        if (!self.hasRelations) {
            self.hasRelations = [repositoryService hasObjectsWithSchemaId:[TLGroup SCHEMA_ID]];
            if (!self.hasRelations) {
                self.hasRelations = [repositoryService hasObjectsWithSchemaId:[TLCallReceiver SCHEMA_ID]];
            }
        }
        
        DDLogVerbose(@"%@ TLRepositoryService.listObjectsWithFactory: schemaId=%@", LOG_TAG, [[TLAccountMigration SCHEMA_ID] toString]);
        [repositoryService listObjectsWithFactory:TLAccountMigration.FACTORY filter:nil withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> * _Nullable objectIds) {
            [self onListAccountMigrations:objectIds errorCode:errorCode];
        }];
        return;
    }
    
    if ((self.state & GET_OBJECT_IDS_DONE) == 0) {
        return;
    }
    
    //
    // Step 2a: create the device migration twincode and indicate our version of AccountMigrationService.
    //
    
    if ((self.state & CREATE_TWINCODE) == 0) {
        self.state |= CREATE_TWINCODE;
        
        NSMutableArray *twincodeFactoryAttributes = [NSMutableArray array];
        [TLPairProtocol setTwincodeAttributePair:twincodeFactoryAttributes];

        NSMutableArray *twincodeOutboundAttributes = [NSMutableArray array];
        [TLTwinmeAttributes setTwincodeAttributeAccountMigration:twincodeOutboundAttributes name:TLAccountMigrationService.VERSION hasRelations:self.hasRelations];
       
        DDLogVerbose(@"%@ TLTwincodeFactoryService.createTwincode: twincodeFactoryAttributes=%@ twincodeOutboundAttributes=%@", LOG_TAG, twincodeFactoryAttributes, twincodeOutboundAttributes);

        [[self.twinmeContext getTwincodeFactoryService] createTwincodeWithFactoryAttributes:twincodeFactoryAttributes inboundAttributes:nil outboundAttributes:twincodeOutboundAttributes switchAttributes:nil twincodeSchemaId:TLAccountMigration.SCHEMA_ID withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeFactory * _Nullable twincodeFactory) {
            [self onCreateTwincodeFactory:twincodeFactory errorCode:errorCode];
        }];
        return;
    }
    
    if((self.state & CREATE_TWINCODE_DONE) == 0){
        return;
    }
    
    //
    // Step 2b: Update the device migration twincode and indicate our version of AccountMigrationService,
    //          to make sure we won't send an old (and incompatible) version number to the peer.
    //
    
    if ((self.state & UPDATE_TWINCODE) == 0) {
        self.state |= UPDATE_TWINCODE;
        
        if (!self.accountMigration || !self.accountMigration.twincodeOutbound) {
            // We should have an AccountMigration with a twincode at this point.
            // Skip twincode update and hope for the best...
            DDLogVerbose(@"%@ UPDATE_TWINCODE step required but accountMigration or its twincodeOutbound is null.", LOG_TAG);
            self.state |= UPDATE_TWINCODE_DONE;
        } else {
            TLTwincodeOutbound *twincodeOutbound = self.accountMigration.twincodeOutbound;
            
            NSMutableArray *twincodeOutboundAttributes = [NSMutableArray array];
            [TLTwinmeAttributes setTwincodeAttributeAccountMigration:twincodeOutboundAttributes name:TLAccountMigrationService.VERSION hasRelations:self.hasRelations];

            [[self.twinmeContext getTwincodeOutboundService] updateTwincodeWithTwincode:twincodeOutbound attributes:twincodeOutboundAttributes deleteAttributeNames:nil withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound * _Nullable twincodeOutbound) {
                [self onUpdateTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
    }
    
    if((self.state & UPDATE_TWINCODE_DONE) == 0){
        return;
    }
    
    //
    // Step 3: create the DeviceMigration object.
    //
    if (self.twincodeFactory) {
        if ((self.state & CREATE_OBJECT) == 0) {
            self.state |= CREATE_OBJECT;
            
            [[self.twinmeContext getRepositoryService] createObjectWithFactory:TLAccountMigration.FACTORY accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject>  _Nonnull object) {
                TLAccountMigration *accountMigration = (TLAccountMigration *)object;
                [accountMigration setTwincodeFactory:self.twincodeFactory];
            } withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject>  _Nullable object) {
                [self onCreateObject:object errorCode:errorCode];
            }];
            return;
        }
        
        if ((self.state & CREATE_OBJECT_DONE) ==0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    self.onCreateAccountMigration(TLBaseServiceErrorCodeSuccess, self.accountMigration);
    
    [self stop];
}

- (void)onListAccountMigrations:(nullable NSArray<id<TLRepositoryObject>> *)accountMigrations errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetAccountMigrationObjects: errorCode=%ud objectIds=%@", LOG_TAG, errorCode, accountMigrations);
    
    self.state |= GET_OBJECT_IDS_DONE;
    
    if (accountMigrations) {
        for (id<TLRepositoryObject> object in accountMigrations) {
            TLAccountMigration *accountMigration = (TLAccountMigration *)object;
            
            // If this account migration object is not bound and has no associated peer twincode, we can use it.
            if (!accountMigration.isBound && !accountMigration.peerTwincodeOutboundId && !self.accountMigration && accountMigration.twincodeOutbound) {
                self.state |= CREATE_TWINCODE | CREATE_TWINCODE_DONE | CREATE_OBJECT | CREATE_OBJECT_DONE;
                self.accountMigration = accountMigration;
            } else {
                [self.twinmeContext deleteAccountMigrationWithAccountMigration:accountMigration withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *  _Nullable uuid) {}];
            }
        }
    }
    
    if (!self.accountMigration) {
        // No existing migration twincode => nothing to update.
        self.state |= UPDATE_TWINCODE | UPDATE_TWINCODE_DONE;
    }
    
    [self onOperation];
}

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateTwincodeFactory: errorCode=%ud twincodeFactory=%@", LOG_TAG, errorCode, twincodeFactory);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeFactory) {
        [self onErrorWithOperationId:CREATE_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }
    
    self.state |= CREATE_TWINCODE_DONE;
    
    self.twincodeFactory = twincodeFactory;
    [self onOperation];
}

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateTwincodeOutbound: errorCode=%ud twincodeOutbound=%@", LOG_TAG, errorCode, twincodeOutbound);

    if (errorCode == TLBaseServiceErrorCodeItemNotFound && self.accountMigration) {
        // It can happen that the twincode has been deleted but we still have the AccountMigration object.
        // This occurs during a successful migration because we are sending the database to the peer and
        // once the migration is done, we delete and unbind the twincode on the first device.  When we start
        // again on the second device, we still see the AccountMigration object but its twincode is now invalid.
        [self.twinmeContext deleteAccountMigrationWithAccountMigration:self.accountMigration withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *  _Nullable uuid) {
            // We have to wait for the delete operation to complete and restart the whole process.
            self.accountMigration = nil;
            self.state = 0;
            [self onOperation];
        }];
        return;

    } else if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
        [self onErrorWithOperationId:UPDATE_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }
    
    self.state |= UPDATE_TWINCODE_DONE;
    
    self.accountMigration.twincodeOutbound = twincodeOutbound;
    [self onOperation];
}


- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateObject: errorCode=%ud object=%@", LOG_TAG, errorCode, object);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:CREATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }
    
    self.state |= CREATE_OBJECT_DONE;
    
    self.accountMigration = (TLAccountMigration *)object;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %ud errorCode=%ud errorParameter=%@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        
        return;
    }

    self.onCreateAccountMigration(errorCode, nil);
    
    [self stop];
}

@end
