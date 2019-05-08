//
//  DLibFaceFeatureItem.h
//  BBFaceLandmarking
//
//  Created by Feng Stone on 2019/1/6.
//  Copyright © 2019 fengshi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
#import "DLibFaceFeatureStruct.h"

extern int VIDS_FR[28];

@interface DLibFaceFeatureItem : NSObject <NSCoding>

@property (atomic, assign) CGSize image_size;
@property (atomic, assign) CGRect face_rect;
@property (atomic, assign) DLibFaceKeyPoints key_points;

@property (atomic, assign) DLibFaceFeatures features_le;
@property (atomic, assign) DLibFaceFeatures features_re;
@property (atomic, assign) DLibFaceFeatures features_leb;
@property (atomic, assign) DLibFaceFeatures features_reb;
@property (atomic, assign) DLibFaceFeatures features_nu;
@property (atomic, assign) DLibFaceFeatures features_nd;
@property (atomic, assign) DLibFaceFeatures features_mu;
@property (atomic, assign) DLibFaceFeatures features_md;

- (void)extractFaceFeatures;
- (DLibFaceKeyPoints *)keyPointsRef;
- (UIImage *)makeFaceShape;
- (UIImage *)extractFaceArea;

@end
