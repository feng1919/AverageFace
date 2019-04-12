//
//  ViewController.m
//  AverageFace
//
//  Created by Feng Stone on 2019/4/9.
//  Copyright © 2019 fengshi. All rights reserved.
//

#import "ViewController.h"
#import "GPUImage/GPUImageView.h"
#import "GPUImage/GPUImagePicture.h"
#import "GPUImage/GPUImageTwoInputFilter.h"
#import "SettingView.h"
#import "DLibFaceFeatureItem.h"
#import "DLibFaceFeatureProcess.h"
#import "FaceMorphFilter.h"

@interface ViewController () <SettingViewDelegate>

@property (nonatomic, strong) GPUImageView *renderView;
@property (nonatomic, strong) SettingView *settingView;

@property (nonatomic, strong) GPUImagePicture *pictureClinton;
@property (nonatomic, strong) GPUImagePicture *pictureTrump;

//@property (nonatomic, strong) DLibFaceFeatureItem *faceFeaturesClinton;
//@property (nonatomic, strong) DLibFaceFeatureItem *faceFeaturesTrump;

@property (nonatomic, strong) FaceMorphFilter *faceMorphFilter;

@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    const CGFloat boundsWidth = CGRectGetWidth(self.view.bounds);
    const CGFloat boundsHeight = CGRectGetHeight(self.view.bounds);
    const CGFloat settingViewHeight = 150;
    
    self.renderView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, boundsWidth, boundsHeight-settingViewHeight)];
    self.renderView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);
    [self.renderView setBackgroundColor:[UIColor whiteColor]];
    [self.renderView setBackgroundColorRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    [self.renderView setFillMode:kGPUImageFillModePreserveAspectRatio];
    [self.view addSubview:self.renderView];
    
    self.settingView = [[SettingView alloc] initWithFrame:CGRectMake(0, boundsHeight-settingViewHeight, boundsWidth, settingViewHeight)];
    self.settingView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin);
    self.settingView.delegate = self;
    [self.view addSubview:self.settingView];
    
    self.faceMorphFilter = [[FaceMorphFilter alloc] init];
    self.faceMorphFilter.skinIntensity = 0.5f;
    self.faceMorphFilter.shapeIntensity = 0.5f;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSString *imgPath = [[NSBundle mainBundle] pathForResource:@"Cruz" ofType:@"png"];
    UIImage *imageClinton = [UIImage imageWithContentsOfFile:imgPath];
    self.pictureClinton = [[GPUImagePicture alloc] initWithImage:imageClinton];
    GPUImageFilter *filter1 = [[GPUImageFilter alloc] init];
    [self.pictureClinton addTarget:filter1];
    [filter1 addTarget:self.faceMorphFilter atTextureLocation:1];
    
    imgPath = [[NSBundle mainBundle] pathForResource:@"Trump" ofType:@"png"];
    UIImage *imageTrump = [UIImage imageWithContentsOfFile:imgPath];
    self.pictureTrump = [[GPUImagePicture alloc] initWithImage:imageTrump];
    GPUImageFilter *filter2 = [[GPUImageFilter alloc] init];
    [self.pictureTrump addTarget:filter2];
    [filter2 addTarget:self.faceMorphFilter atTextureLocation:0];
    
    [self.faceMorphFilter addTarget:self.renderView];
    
    DLibFaceFeatureProcess *processor = [DLibFaceFeatureProcess sharedInstance];
    [processor processImage:imageClinton completion:^(DLibFaceFeatureItem * featureItem1) {
        
        [featureItem1 extractFaceFeatures];
        self.faceMorphFilter.faceFeatureMine = featureItem1;
        [processor processImage:imageTrump completion:^(DLibFaceFeatureItem * featureItem2) {
            
            [featureItem2 extractFaceFeatures];
            self.faceMorphFilter.faceFeatureModel = featureItem2;
            [self.faceMorphFilter normalizePhotos];
            
            UIImage *image = [featureItem2 makeFaceShape];

            runAsynchronouslyOnVideoProcessingQueue(^{
                self.faceMorphFilter.maskImage = [[GPUImagePicture alloc] initWithImage:image];
                [self render];
            });
        }];
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
//    [self performSelector:@selector(render) withObject:nil afterDelay:0.0f];
}

- (void)render {
    [self.pictureClinton processImage];
    [self.pictureTrump processImage];
}

#pragma mark - SetttingViewDelegate

- (void)SettingView:(SettingView *)settingView didChangeFaceliftIntensity:(CGFloat)faceliftIntensity {
    self.faceMorphFilter.skinIntensity = faceliftIntensity;
    [self render];
}

- (void)SettingView:(SettingView *)settingView didChangeEyelargeIntensity:(CGFloat)eyelargeIntensity {
    self.faceMorphFilter.shapeIntensity = eyelargeIntensity;
    [self render];
}

@end
