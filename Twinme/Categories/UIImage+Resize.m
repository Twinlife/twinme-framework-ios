/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Zhuoyu Ma (Zhuoyu.Ma@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */

#import "UIImage+Resize.h"

//
// Implementation: UIImage (Resize)
//

#define MAX_AVATAR_WIDTH 256
#define MAX_AVATAR_HEIGHT 256

@implementation UIImage (Resize)

- (UIImage *)resizeImage {
    
    CGSize size = [self size];
    if (size.width <= MAX_AVATAR_HEIGHT && size.height <= MAX_AVATAR_HEIGHT) {
        return self;
    }
    
    CGSize targetSize = CGSizeMake(MAX_AVATAR_WIDTH, MAX_AVATAR_HEIGHT);
    CGFloat width = size.width;
    CGFloat height = size.height;
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    CGPoint thumbnailPoint = CGPointMake(0., 0.);
    
    if (!CGSizeEqualToSize(size, targetSize)) {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        CGFloat scaleFactor = MAX(widthFactor, heightFactor);
        scaledWidth = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        if (widthFactor > heightFactor) {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
        } else {
            if (widthFactor < heightFactor) {
                thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
            }
        }
    }
    
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.); // crop
    
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    
    [self drawInRect:thumbnailRect];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (UIImage *)resizeMedia:(CGSize)newSize {
    
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    format.opaque = NO;
    UIGraphicsImageRenderer *imageRenderer = [[UIGraphicsImageRenderer alloc] initWithSize:newSize format:format];
    UIImage *resized = [imageRenderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [self drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    }];
        
    return resized;
}

@end
