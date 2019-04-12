//
//  DLibFaceFeatureProcess.h
//  AverageFace
//
//  Created by Feng Stone on 2019/4/11.
//  Copyright © 2019 fengshi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DLibFaceFeatureItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface DLibFaceFeatureProcess : NSObject

+ (id)sharedInstance;
- (void)processImage:(UIImage *)image completion:(void(^)(DLibFaceFeatureItem *))completion;

@end

NS_ASSUME_NONNULL_END
