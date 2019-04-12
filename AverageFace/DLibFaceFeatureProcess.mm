//
//  DLibFaceFeatureProcess.m
//  AverageFace
//
//  Created by Feng Stone on 2019/4/11.
//  Copyright © 2019 fengshi. All rights reserved.
//

#import "DLibFaceFeatureProcess.h"
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#include <dlib/image_processing.h>
#include <dlib/image_io.h>

using namespace dlib;

#define DEBUG_DLIB 0

@interface DLibFaceFeatureProcess() {
    dispatch_queue_t face_detect_queue;
    array2d<rgb_alpha_pixel> image_buffer;
    shape_predictor sp;
    
    CIContext *faceDetectContext;
    //    NSDictionary *faceDetectParams;
    CIDetector *faceDetector;
}

CGRect transformForFrontalFace(CGRect& faceBound);

@end

static DLibFaceFeatureProcess *_sharedDLibFaceFeatureProcessor = nil;

@implementation DLibFaceFeatureProcess

+ (void)initialize {
    if (self == [DLibFaceFeatureProcess class]) {
        _sharedDLibFaceFeatureProcessor = [[DLibFaceFeatureProcess alloc] init];
    }
}

+ (id)sharedInstance {
    return _sharedDLibFaceFeatureProcessor;
}

- (instancetype)init {
    if (self = [super init]) {
        face_detect_queue = dispatch_queue_create("com.fengshi.facedetectqueue", DISPATCH_QUEUE_PRIORITY_DEFAULT);

        NSString *spName = @"shape_predictor_68_face_landmarks";
        NSString *modelFileName = [[NSBundle mainBundle] pathForResource:spName ofType:@"dat"];
        std::string modelFileNameCString = [modelFileName UTF8String];
        dlib::deserialize(modelFileNameCString) >> sp;

        faceDetectContext = [CIContext context];
        //        faceDetectParams = @{CIDetectorImageOrientation : @(1)};
        faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace
                                          context:faceDetectContext
                                          options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
    }
    return self;
}

- (void)processImage:(UIImage *)image completion:(void (^)(DLibFaceFeatureItem *))completion {
    
    if (image == nil) {
        return;
    }
    
    if (completion == NULL) {
        return;
    }
    
    static CGColorSpaceRef colorSpace = NULL;
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    dispatch_async(face_detect_queue, ^{
        
        int width = image.size.width;
        int height = image.size.height;
        int bufferSize = width * height * 4;
        int bpr = width << 2;
        
        if (width <=0 || height <= 0) {
            completion(nil);
            return;
        }
        
        if (num_rows(image_buffer) != height || num_columns(image_buffer) != width) {
            NSLog(@"dlib buffer size: %dx%d", width, height);
            image_buffer.set_size(height, width);
        }
        
        Byte *rawImagePixels = (Byte *)malloc(bufferSize);
        
        CGContextRef context = CGBitmapContextCreate(rawImagePixels, width, height, 8, width*4, colorSpace,
                                                     kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
//                                                     kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image.CGImage);
//        CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
//        CGContextFillRect(context, CGRectMake(-1, height-5, 10, 10));
        
        Byte *faceBuffer = (Byte *)image_data(image_buffer);
        NSAssert(faceBuffer != NULL, @"Invalid face buffer...");
        for (int i = 0; i < height; i++) {
//            memcpy(faceBuffer+i*bpr, rawImagePixels+(height-i-1)*bpr, bpr);
            memcpy(faceBuffer+i*bpr, rawImagePixels+i*bpr, bpr);
        }
        
        CIImage *imageFromFramebuffer = [CIImage imageWithBitmapData:[NSData dataWithBytes:faceBuffer length:bufferSize]
                                                         bytesPerRow:bpr
                                                                size:CGSizeMake(width, height)
                                                              format:kCIFormatRGBA8
                                                          colorSpace:colorSpace];
        
        NSArray *features = [_sharedDLibFaceFeatureProcessor->faceDetector featuresInImage:imageFromFramebuffer options:nil];
        
        if (features.count == 0) {
            completion(nil);
            return;
        }
        
        DLibFaceFeatureItem *item = [[DLibFaceFeatureItem alloc] init];
        item.image_size = CGSizeMake(width, height);
        
        CIFeature *feature = features.firstObject;
        CGRect faceRect = feature.bounds;
        faceRect.origin.y = height - faceRect.size.height - faceRect.origin.y;
        item.face_rect = faceRect;
        
        dlib::rectangle oneFaceRect(faceRect.origin.x, faceRect.origin.y, CGRectGetMaxX(faceRect), CGRectGetMaxY(faceRect));
    
        dlib::full_object_detection shape = sp(image_buffer, oneFaceRect);
        
        NSAssert(shape.num_parts() == 68, @"Invalid shape parts count");
        
        DLibFaceKeyPoints *keyPoints = [item keyPointsRef];
        keyPoints->num_of_points = 71;
        CGPoint *fp = keyPoints->points;
        for (int k = 0; k < shape.num_parts(); k++) {
            point p = shape.part(k);
            fp[k].x = p.x();
            fp[k].y = p.y();
        }
        fp[68].x = (fp[19].x+fp[24].x)*0.5f;
        fp[68].y = (fp[19].y+fp[24].y)*0.5f;
        
        fp[69].x = fp[68].x*2.0f-fp[27].x;
        fp[69].y = fp[68].y*2.0f-fp[27].y;
        
        fp[70].x = fp[68].x*2.0f-fp[30].x;
        fp[70].y = fp[68].y*2.0f-fp[30].y;
        
#if DEBUG_DLIB
        NSLog(@"face rect: %@", NSStringFromCGRect(faceRect));
        NSLog(@"face max y: %g", CGRectGetMaxY(faceRect));
        NSLog(@"point 8: %@", NSStringFromCGPoint(fp[8]));
        
        faceRect.origin.y = height - faceRect.size.height - faceRect.origin.y;
        CGContextSetLineWidth(context, 1.0f);
        CGContextSetStrokeColorWithColor(context, [UIColor redColor].CGColor);
        CGContextAddRect(context, faceRect);
        CGContextStrokeRect(context, faceRect);
        
//        CGFloat max_y = CGRectGetMaxY(faceRect);
        for (int i = 0; i < 71; i++) {
            CGPoint p = fp[i];
            CGContextStrokeEllipseInRect(context, CGRectMake(p.x, height-p.y, 1, 1));
        }
        CGContextStrokeRect(context, CGRectMake(10, 10, 10, 10));
        
        CGImageRef image_ref = CGBitmapContextCreateImage(context);
        UIImage *newImage = [UIImage imageWithCGImage:image_ref];
        UIImageWriteToSavedPhotosAlbum(newImage, nil, nil, nil);
        CGImageRelease(image_ref);
#endif
        
        CGContextRelease(context);
        free(rawImagePixels);
        
        completion(item);
        
    });
}

@end
