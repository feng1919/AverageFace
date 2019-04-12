//
//  FaceMorphFilter.h
//  BBFaceLandmarking
//
//  Created by Feng Stone on 2019/1/6.
//  Copyright © 2019 fengshi. All rights reserved.
//

#import "GPUImage/GPUImageTwoInputFilter.h"
#import "GPUImage/GPUImagePicture.h"
#import "DLibFaceFeatureItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface FaceMorphFilter : GPUImageTwoInputFilter

@property (nonatomic, strong) GPUImagePicture *maskImage;

@property (nonatomic, strong) DLibFaceFeatureItem *faceFeatureMine;
@property (nonatomic, strong) DLibFaceFeatureItem *faceFeatureModel;

@property (atomic, assign) CGFloat shapeIntensity;
@property (atomic, assign) CGFloat skinIntensity;

- (void)normalizePhotos;

@end

NS_ASSUME_NONNULL_END
