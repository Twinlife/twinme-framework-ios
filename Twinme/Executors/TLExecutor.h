/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwinmeContextImpl.h"

//
// Interface: TLExecutor
//

/**
 * Twinme Executor
 *
 * The TLExecutor is the base class of executors that should have a single instance at a given time.
 * The executor handles the base operations used by all executors and it also maintains the state of the executor.
 * The executor handles a list of blocks that are executed as soon as the executor has finished and is stopped successfully or not.
 *
 * The execute() method is used to add such execution block to the queue.
 * The stop() method will handle the execution of all blocks that have been queued.
 *
 * The pattern to create a single executor of a given kind is maintained in TLTwinmeContext and follows:
 * - the executor instance is associated with a unique name and stored in the 'executors' dictionary.
 * - the synchronization is made on the 'executors' instance to protect lookup, insertion and removal.
 * - the dictionary is look at for the unique name and the instance is used if it existed.
 * - a new instance is created if it did not exist and added to the 'executors' dictionary.
 * - the specific work is queued by running the execute() operation on the TLExecutor instance.
 *  In most cases, that specific work involves calling a resolveFindXXX() with a predicate and consumer block.
 * - if a new instance was created, it is started.
 *
 * When the TLExecutor finished, it calls some onXXX() operation on the TLTwinmeContext and that operation is then
 * responsible for removing the TLExecutor instance from the 'executors' dictionary.
 *
 * The execute() and stop() are protected against concurrent accesses. It is possible that execute() is called and the executor
 * is stopped. In that case, the execute() operation will execute the block immediately.
 *
 * The TLExecutor is useful to retrieve:
 * - the list of spaces,
 * - the list of contacts,
 * - the list of groups,
 * - the list of notifications
 */
@class TLTwinmeContext;

@interface TLExecutor : NSObject

@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (nonatomic, readonly) int64_t requestId;
@property (nonatomic, readonly, nonnull) NSMutableDictionary *requestIds;
@property (nonatomic) int state;
@property (nonatomic) BOOL restarted;
@property (nonatomic) BOOL stopped;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId;

- (void)start;

/// Execute the given block as soon as the executor has finished.
- (void)execute:(nonnull void (^)(void))block;

/// Allocate a new request id for the operation.
- (int64_t)newOperation:(int) operationId;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onTwinlifeOffline;

- (void)onOperation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

/// Cleanup and run the executor blocks that have been queued by execute().
- (void)stop;

@end

//
// Interface: TLExecutorTwinmeContextDelegate
//

@interface TLExecutorTwinmeContextDelegate:NSObject <TLTwinmeContextDelegate>

@property (nullable) TLExecutor* executor;

- (nonnull instancetype)initWithExecutor:(nonnull TLExecutor *)executor;

- (void)dispose;

@end
