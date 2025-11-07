/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>

#import "TLGetTwincodeAction.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_TWINCODE = 1 << 0;
static const int GET_TWINCODE_DONE = 1 << 1;
static const int GET_TWINCODE_IMAGE = 1 << 2;
static const int GET_TWINCODE_IMAGE_DONE = 1 << 3;

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.1
//

//
// Interface(): TLGetTwincodeAction
//

@interface TLGetTwincodeAction ()

@property (nonatomic, nullable) void (^onGetTwincodeAction) (TLBaseServiceErrorCode errorCode, NSString *name, UIImage *avatar);
@property (nonatomic) int state;
@property (nonatomic, nullable) TLImageId *twincodeAvatarId;
@property (nonatomic, nullable) NSString *twincodeName;

- (void)onTwinlifeReady;

- (void)fireErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLGetTwincodeAction
//

#undef LOG_TAG
#define LOG_TAG @"TLGetTwincodeAction"

@implementation TLGetTwincodeAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSString * _Nullable name, UIImage * _Nullable avatar))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ twincodeOutboundId: %@", LOG_TAG, twinmeContext, twincodeOutboundId);
    
    self = [super initWithTwinmeContext:twinmeContext timeLimit:10.0];
    
    if (self) {
        _twincodeOutboundId = twincodeOutboundId;
        _onGetTwincodeAction = block;
    }
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);

    [self onOperation];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    // Get the twincode information.
    if ((self.state & GET_TWINCODE) == 0) {
        self.state |= GET_TWINCODE;
        
        DDLogVerbose(@"%@ getTwincodeWithRequestId: %lld twincodeOutboundId: %@", LOG_TAG, self.requestId, self.twincodeOutboundId);
        [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.twincodeOutboundId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {

            self.state |= GET_TWINCODE_DONE;
            if (errorCode != TLBaseServiceErrorCodeSuccess) {
                [self fireErrorWithErrorCode:errorCode];
                return;
            }

            self.twincodeName = [twincodeOutbound name];
            self.twincodeAvatarId = [twincodeOutbound avatarId];

            if (!self.twincodeAvatarId && self.onGetTwincodeAction) {
                self.onGetTwincodeAction(errorCode, self.twincodeName, nil);
                self.onGetTwincodeAction = nil;
            }
            
            [self onOperation];
        }];
        return;
    }
        
    if ((self.state & GET_TWINCODE_DONE) == 0) {
        return;
    }
    
    //
    // We must get the twincode avatar id.
    //
    if (self.twincodeAvatarId) {

        if ((self.state & GET_TWINCODE_IMAGE) == 0) {
            self.state |= GET_TWINCODE_IMAGE;

            DDLogVerbose(@"%@ getImageWithImageId: %@", LOG_TAG, self.twincodeAvatarId);
            [[self.twinmeContext getImageService] getImageWithImageId:self.twincodeAvatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {

                self.state |= GET_TWINCODE_IMAGE_DONE;

                if (self.onGetTwincodeAction) {
                    self.onGetTwincodeAction(errorCode, self.twincodeName, image);
                    self.onGetTwincodeAction = nil;
                }
                [self onFinish];
            }];
            return;
        }
        if ((self.state & GET_TWINCODE_IMAGE_DONE) == 0) {
            return;
        }
    }

    [self onFinish];
}

- (void)fireErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ fireErrorWithErrorCode %d", LOG_TAG, errorCode);

    if (self.onGetTwincodeAction) {
        self.onGetTwincodeAction(errorCode, nil, nil);
        self.onGetTwincodeAction = nil;
    }

    [self onFinish];
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    self.onGetTwincodeAction = nil;
    [self onFinish];
}

@end
