/*
 *  Copyright (c) 2017-2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Thibaud David (contact@thibauddavid.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

//
// Interface: PhoneBookContact
//

@interface PhoneBookContact : NSObject

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *firstname;
@property (strong, nonatomic) NSString *phoneNumber;
@property (strong, nonatomic) UIImage *avatar;

- (NSString *)fullname;

@end
