/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLInvocation
//

@protocol TLRepositoryObject;

//
// version: 1.2
//

@interface TLInvocation : NSObject

@property (nonatomic, readonly, nonnull) NSUUID *uuid;
@property (nonatomic, readonly, nonnull) id<TLRepositoryObject> receiver;
@property (nonatomic, readonly) BOOL background;

- (nonnull instancetype)initWithId:(nonnull NSUUID*)uuid receiver:(nonnull id<TLRepositoryObject>)receiver background:(BOOL)background;

@end
