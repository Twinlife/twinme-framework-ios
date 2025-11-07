/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwinmeContext.h"

/**
 * Interface: TLTwinmeAction
 *
 * Base class of actions that provide high level operations on top of TwinmeContext API.
 *
 * - A TwinmeAction implements the TwinmeContext observer to simplify getting the results,
 * - It defines a deadline time after which the action must be canceled.
 * - The onOperation() must be implemented by derived classes.
 * - TwinmeAction are sorted on their Comparable so that the first one to expire can be identified.
 * - The TwinmeContext records the pending actions through the startAction() method which is invoked
 * when the start() method is called.
 * - When an action is finished, the TwinmeContext finishAction() is called.
 * - The TwinmeContext manages timeouts for the actions and calls fireTimeout().
 */
@interface TLTwinmeAction : NSObject <TLTwinmeContextDelegate>

@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (nonatomic, readonly, nonnull) NSDate *deadlineTime;
@property (nonatomic, readonly) int64_t requestId;
@property (nonatomic) BOOL isOnline;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext timeLimit:(NSTimeInterval)timeLimit;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId timeLimit:(NSTimeInterval)timeLimit;

/// Compare the two actions to order them in the queue in deadline increasing order.
- (NSComparisonResult)compareWithAction:(nonnull TLTwinmeAction *)action;

/// Start the action.
- (void)start;

/// Handle the action.
- (void)onOperation;

/// Called when the action is finished to cleanup.
- (void)onFinish;

/// Fire the error with the given error code.
- (void)fireErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

/// Fire the timeout when the action deadline has passed.
- (void)fireTimeout;

/// Cancel the operation.
- (void)cancel;

@end
