/*
 *  Copyright (c) 2017 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Thibaud David (contact@thibauddavid.com)
 */

//
// Implementation: PhoneBookContact
//

#import "PhoneBookContact.h"

@implementation PhoneBookContact

- (NSString *)fullname {
    
    if(self.name && self.firstname) {
        return [NSString stringWithFormat:@"%@ %@", self.firstname, self.name];
    }
    if (self.name) {
        return self.name;
    }
    if (self.firstname) {
        return self.firstname;
    }
    return @"";
}

@end
