//
//  DLibFaceFeatureItem.m
//  BBFaceLandmarking
//
//  Created by Feng Stone on 2019/1/6.
//  Copyright © 2019 fengshi. All rights reserved.
//

#import "DLibFaceFeatureItem.h"

//const int VIDS_LF[9] = {0,1,2,3,4,5,6,7,8};
//const int VIDS_RF[9] = {8,9,10,11,12,13,14,15,16};
//const int VIDS_LE[6] = {36,37,38,39,40,41};
//const int VIDS_LEB[5] = {17,18,19,20,21};
//const int VIDS_RE[6] = {42,43,44,45,46,47};
//const int VIDS_REB[5] = {22,23,24,25,26};
//const int VIDS_NU[4] = {27,28,29,30};
//const int VIDS_ND[5] = {31,32,33,34,35};
//const int VIDS_MU[12] = {48,49,50,51,52,53,54,60,61,62,63,64};
//const int VIDS_MD[12] = {54,55,56,57,58,59,48,64,65,66,67,60};

DLibFaceStruct DLibDefaultFaceStruct =
{
    {0,1,2,3,4,5,6,7,8},
    {8,9,10,11,12,13,14,15,16},
    {36,37,38,39,40,41},
    {17,18,19,20,21},
    {42,43,44,45,46,47},
    {22,23,24,25,26},
    {27,28,29,30},
    {31,32,33,34,35},
    {48,49,50,51,52,53,54,60,61,62,63,64},
    {54,55,56,57,58,59,48,64,65,66,67,60},
};

int VIDS_FR[28] = {
    0,1,2,3,4,5,6,7,8,9,
    10,11,12,13,14,15,16,
    26,25,24,23,22,21,20,19,18,17,0
};

@implementation DLibFaceFeatureItem

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        NSUInteger bufferLength = 0;
        const uint8_t *kp_buffer = [aDecoder decodeBytesForKey:@"KeyPoints" returnedLength:&bufferLength];
        if (bufferLength == sizeof(DLibFaceKeyPoints)) {
            memcpy(&_key_points, kp_buffer, sizeof(DLibFaceKeyPoints));
        }
        
        const uint8_t *fr_buffer = [aDecoder decodeBytesForKey:@"FaceRect" returnedLength:&bufferLength];
        if (bufferLength == sizeof(CGRect)) {
            memcpy(&_face_rect, fr_buffer, sizeof(CGRect));
        }
        
        const uint8_t *is_buffer = [aDecoder decodeBytesForKey:@"ImageSize" returnedLength:&bufferLength];
        if (bufferLength == sizeof(CGSize)) {
            memcpy(&_image_size, is_buffer, sizeof(CGSize));
        }
        
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBytes:(Byte *)&_key_points length:sizeof(DLibFaceKeyPoints) forKey:@"KeyPoints"];
    [aCoder encodeBytes:(Byte *)&_face_rect length:sizeof(CGRect) forKey:@"FaceRect"];
    [aCoder encodeBytes:(Byte *)&_image_size length:sizeof(CGSize) forKey:@"ImageSize"];
}

- (NSString *)description {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"NumberOFKeyPoints"] = @(_key_points.num_of_points);
    dict[@"FaceRect"] = [NSString stringWithFormat:@"[%g,%g,%g,%g]", _face_rect.origin.x, _face_rect.origin.y, _face_rect.size.width, _face_rect.size.height];
    return [dict description];
}

- (DLibFaceKeyPoints *)keyPointsRef {
    return &_key_points;
}

- (void)extractFaceFeatures {
    
    if (CGRectGetWidth(_face_rect) < 10.0f || CGRectGetHeight(_face_rect) < 10.0f) {
        return;
    }
    
    CGPoint *kp = malloc(_key_points.num_of_points * sizeof(CGPoint));
    for (int i = 0; i < _key_points.num_of_points; i ++) {
        CGPoint p = _key_points.points[i];
        kp[i].x = p.x;//MIN(MAX(p.x, 0.0f), width-1.0f) / width;
        kp[i].y = p.y;//MIN(MAX(p.y, 0.0f), height-1.0f) / height;
    }
    
    ExtractFeaturesFromFace(kp, DLibDefaultFaceStruct.VIDS_LE, 6, &_features_le);
    ExtractFeaturesFromFace(kp, DLibDefaultFaceStruct.VIDS_RE, 6, &_features_re);
    ExtractFeaturesFromFace(kp, DLibDefaultFaceStruct.VIDS_LEB, 5, &_features_leb);
    ExtractFeaturesFromFace(kp, DLibDefaultFaceStruct.VIDS_REB, 5, &_features_reb);
    ExtractFeaturesFromFace(kp, DLibDefaultFaceStruct.VIDS_NU, 4, &_features_nu);
    ExtractFeaturesFromFace(kp, DLibDefaultFaceStruct.VIDS_ND, 5, &_features_nd);
    ExtractFeaturesFromFace(kp, DLibDefaultFaceStruct.VIDS_MU, 12, &_features_mu);
    ExtractFeaturesFromFace(kp, DLibDefaultFaceStruct.VIDS_MD, 12, &_features_md);
    
    free(kp);
    kp = NULL;
}

- (UIImage *)makeFaceShape {
    CGFloat width = 64.0f;
    CGFloat height = 64.0f;
    
    static CGColorSpaceRef colorSpace = NULL;
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width*4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillRect(context, CGContextGetClipBoundingBox(context));
    
    UIBezierPath *bezierPath = [self bezierPathOfFaceKeyPoints];
    CGContextAddPath(context, [bezierPath CGPath]);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillPath(context);
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGContextRelease(context);
    
//    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    
    return image;
}

- (UIBezierPath *)bezierPathOfFaceKeyPoints {
    
    CGFloat image_width = _image_size.width;
    CGFloat image_height = _image_size.height;
    CGFloat scale = 64.0f;
    int num_of_points = 28;
    
    CGPoint *bezier_points = malloc(num_of_points * sizeof(CGPoint));
    for (int i = 0; i < num_of_points; i++) {
        int vid = VIDS_FR[i];
        CGPoint p = _key_points.points[vid];
        p.x = roundf(scale * p.x / image_width);
        p.y = scale - roundf(scale * p.y / image_height);
        bezier_points[i] = p;
    }
    
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint:bezier_points[0]];
    for (int i = 1; i < num_of_points; i++) {
        [bezierPath addLineToPoint:bezier_points[i]];
    }
    
    free(bezier_points);
    bezier_points = NULL;
    
    return bezierPath;
}

- (UIImage *)extractFaceArea {
    
    CGFloat image_width = _image_size.width;
    CGFloat image_height = _image_size.height;
    int num_of_points = 28;
    
    CGPoint *bezier_points = malloc(num_of_points * sizeof(CGPoint));
    for (int i = 0; i < num_of_points; i++) {
        int vid = VIDS_FR[i];
        CGPoint p = _key_points.points[vid];
        p.y = image_height - p.y;
        bezier_points[i] = p;
    }
    
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint:bezier_points[0]];
    for (int i = 1; i < num_of_points; i++) {
        [bezierPath addLineToPoint:bezier_points[i]];
    }
    
    free(bezier_points);
    bezier_points = NULL;
    
    
    static CGColorSpaceRef colorSpace = NULL;
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGContextRef context = CGBitmapContextCreate(NULL, image_width, image_height, 8, image_width*4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillRect(context, CGContextGetClipBoundingBox(context));
    
    CGContextAddPath(context, [bezierPath CGPath]);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillPath(context);
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGContextRelease(context);
    
    return image;
}

void ExtractFeaturesFromFace(CGPoint *key_points, int *vids, int num_of_vids, DLibFaceFeatures *fout) {
    CGPoint *pb = malloc(num_of_vids * sizeof(CGPoint));
    for (int i = 0; i < num_of_vids; i ++) {
        int vid = vids[i];
        pb[i] = key_points[vid];
    }
    fout->feature_point = MeanOfPoints(pb, &num_of_vids);
    fout->num_of_features = num_of_vids;
    CalculateVectorsOfPoints(pb, &num_of_vids, &fout->feature_point, fout->feature_list);
    free(pb);
    pb = NULL;
}

CGPoint MeanOfPoints(CGPoint *points, int *num_of_points) {
    double sum_x = 0;
    double sum_y = 0;
    for (int i = 0; i < num_of_points[0]; i++) {
        sum_x += points[i].x;
        sum_y += points[i].y;
    }
    return CGPointMake(sum_x/(double)num_of_points[0], sum_y/(double)num_of_points[0]);
}

void CalculateVectorsOfPoints(CGPoint *points, int*num_of_points, CGPoint *origin, CGVector *outputVectors) {
    for (int i = 0; i < num_of_points[0]; i++) {
        outputVectors[i].dx = points[i].x - origin->x;
        outputVectors[i].dy = points[i].y - origin->y;
    }
}

@end
