/*
 *  Copyright (c) 2014-2017 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "UIImage+ToData.h"
#import "UIImage+Resize.h"

//
// Implementation: UIImage (ToData)
//

@implementation UIImage (ToData)

- (NSData *)toData {
    
    UIImage *resizedImage = [self resizeImage];
    return UIImagePNGRepresentation(resizedImage);
}

@end
