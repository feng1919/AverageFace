//
//  FaceMorphFilter.m
//  BBFaceLandmarking
//
//  Created by Feng Stone on 2019/1/6.
//  Copyright © 2019 fengshi. All rights reserved.
//

#import "FaceMorphFilter.h"
#include "Delaunay/delaunay.h"
#import "GPUImage/GPUImagePicture.h"

NSString *const kFaceMorphBlendVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 attribute vec4 inputTextureCoordinate2;
 
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     textureCoordinate2 = inputTextureCoordinate2.xy;
 }
 );

NSString *const kFaceMorphBlendFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 
 uniform lowp float mixturePercent;
 
 void main()
 {
     lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     lowp vec4 textureColor2 = texture2D(inputImageTexture2, textureCoordinate2);
     lowp vec4 maskColor = texture2D(inputImageTexture3, textureCoordinate);
     
     gl_FragColor = vec4(mix(textureColor.rgb, textureColor2.rgb, textureColor2.a * mixturePercent * maskColor.r), textureColor.a);
 }
 );

@interface FaceMorphFilter () {
    GLint mixUniform;
    GLint maskUniform;
}

@property (nonatomic, assign) DLibFaceFeatures features_le;
@property (nonatomic, assign) DLibFaceFeatures features_leb;
@property (nonatomic, assign) DLibFaceFeatures features_re;
@property (nonatomic, assign) DLibFaceFeatures features_reb;
@property (nonatomic, assign) DLibFaceFeatures features_nu;
@property (nonatomic, assign) DLibFaceFeatures features_nd;
@property (nonatomic, assign) DLibFaceFeatures features_mu;
@property (nonatomic, assign) DLibFaceFeatures features_md;

//@property (nonatomic, strong) GPUImagePicture *maskImage;

@end

@implementation FaceMorphFilter

- (instancetype)init {
    if (self = [super initWithVertexShaderFromString:kFaceMorphBlendVertexShaderString
                            fragmentShaderFromString:kFaceMorphBlendFragmentShaderString]) {
        self.skinIntensity = 0.5f;
        self.shapeIntensity = 0.5f;
        
        mixUniform = [filterProgram uniformIndex:@"mixturePercent"];
        maskUniform = [filterProgram uniformIndex:@"inputImageTexture3"];
        
//        NSString *shapeFile = [[NSBundle mainBundle] pathForResource:@"shape" ofType:@"JPG"];
//        UIImage *image = [UIImage imageWithContentsOfFile:shapeFile];
//        self.maskImage = [[GPUImagePicture alloc] initWithImage:image];
    }
    return self;
}

- (void)normalizePhotos {

    CGSize s1 = _faceFeatureModel.face_rect.size;
    CGSize s2 = _faceFeatureMine.face_rect.size;
    
    CGVector scale = CGVectorMake(s1.width/s2.width, s1.height/s2.height);
    
    _features_le = _faceFeatureMine.features_le;
    NormalizeFeature(&_features_le, &scale);

    _features_re = _faceFeatureMine.features_re;
    NormalizeFeature(&_features_re, &scale);

    _features_leb = _faceFeatureMine.features_leb;
    NormalizeFeature(&_features_leb, &scale);

    _features_reb = _faceFeatureMine.features_reb;
    NormalizeFeature(&_features_reb, &scale);

    _features_nu = _faceFeatureMine.features_nu;
    NormalizeFeature(&_features_nu, &scale);

    _features_nd = _faceFeatureMine.features_nd;
    NormalizeFeature(&_features_nd, &scale);

    _features_mu = _faceFeatureMine.features_mu;
    NormalizeFeature(&_features_mu, &scale);

    _features_md = _faceFeatureMine.features_md;
    NormalizeFeature(&_features_md, &scale);
}

void NormalizeFeature(DLibFaceFeatures *features, CGVector *scale) {
    features->feature_point.x *= scale->dx;
    features->feature_point.y *= scale->dy;
    for (int i = 0; i < features->num_of_features; i ++) {
        features->feature_list[i].dx *= scale->dx;
        features->feature_list[i].dy *= scale->dy;
    }
}

void ApplyFeatures(CGSize *image_size,
                   DLibFaceFeatures *model_features,
                   DLibFaceFeatures *mine_features,
                   int *vids, CGFloat intensity, point *np_list) {
    CGPoint cp = model_features->feature_point;
    for (int i = 0; i < model_features->num_of_features; i ++) {
        CGVector v1 = model_features->feature_list[i];
        CGVector v2 = mine_features->feature_list[i];
        int vid = vids[i];
        np_list[vid].x = (v1.dx+cp.x)+intensity*(v2.dx-v1.dx);
        np_list[vid].y = (v1.dy+cp.y)+intensity*(v2.dy-v1.dy);
        np_list[vid].x /= image_size->width;
        np_list[vid].y /= image_size->height;
    }
}

void CalculateFaceTextureCoordinate(point *np_list, int num_of_points, CGRect face_rect, CGSize image_size,
                                    DLibFaceKeyPoints *key_points) {
    CGFloat width = image_size.width;
    CGFloat height = image_size.height;
    
    for (int i = 0; i < key_points->num_of_points; i++) {
        CGPoint p = key_points->points[i];
        np_list[i].x = MIN(MAX(p.x, 0.0f), width-1.0f) / width;
        np_list[i].y = MIN(MAX(p.y, 0.0f), height-1.0f) / height;
        np_list[i].z = 0.0f;
    }
    np_list[num_of_points-4].x = 0.0f;
    np_list[num_of_points-4].y = 0.0f;
    np_list[num_of_points-4].z = 0.0f;
    np_list[num_of_points-3].x = 0.0f;
    np_list[num_of_points-3].y = 1.0f;
    np_list[num_of_points-3].z = 0.0f;
    np_list[num_of_points-2].x = 1.0f;
    np_list[num_of_points-2].y = 1.0f;
    np_list[num_of_points-2].z = 0.0f;
    np_list[num_of_points-1].x = 1.0f;
    np_list[num_of_points-1].y = 0.0f;
    np_list[num_of_points-1].z = 0.0f;
    
    CGFloat min_x = CGRectGetMinX(face_rect)/width;
    CGFloat max_x = CGRectGetMaxX(face_rect)/width;
    CGFloat mid_x = CGRectGetMidX(face_rect)/width;
    CGFloat min_y = CGRectGetMinY(face_rect)/height;
    CGFloat max_y = CGRectGetMaxY(face_rect)/height;
    CGFloat mid_y = CGRectGetMidY(face_rect)/height;
    
    np_list[num_of_points-5].x = min_x;
    np_list[num_of_points-5].y = min_y;
    np_list[num_of_points-5].z = 0.0f;
    np_list[num_of_points-6].x = min_x;
    np_list[num_of_points-6].y = max_y;
    np_list[num_of_points-6].z = 0.0f;
    np_list[num_of_points-7].x = max_x;
    np_list[num_of_points-7].y = max_y;
    np_list[num_of_points-7].z = 0.0f;
    np_list[num_of_points-8].x = max_x;
    np_list[num_of_points-8].y = min_y;
    np_list[num_of_points-8].z = 0.0f;
    np_list[num_of_points-9].x = mid_x;
    np_list[num_of_points-9].y = min_y;
    np_list[num_of_points-9].z = 0.0f;
    np_list[num_of_points-10].x = max_x;
    np_list[num_of_points-10].y = mid_y;
    np_list[num_of_points-10].z = 0.0f;
    np_list[num_of_points-11].x = mid_x;
    np_list[num_of_points-11].y = max_y;
    np_list[num_of_points-11].z = 0.0f;
    np_list[num_of_points-12].x = min_x;
    np_list[num_of_points-12].y = mid_y;
    np_list[num_of_points-12].z = 0.0f;
}

//- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex {
//    NSLog(@"set input frame buffer texture index: %ld", textureIndex);
//    [super setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
//
//    if (textureIndex == 1) {
//        [newInputFramebuffer lock];
//        CGImageRef imagebuff = [newInputFramebuffer newCGImageFromFramebufferContents];
//        UIImage *testImage = [UIImage imageWithCGImage:imagebuff];
//        CGImageRelease(imagebuff);
//    }
//}

- (void)newFrameReadyAtTime1:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    int num_of_points = [_faceFeatureModel keyPointsRef]->num_of_points + 12;
    point *np_list = malloc(num_of_points * sizeof(point));
    CalculateFaceTextureCoordinate(np_list, num_of_points,
                                   _faceFeatureModel.face_rect, _faceFeatureModel.image_size,
                                   [_faceFeatureModel keyPointsRef]);
    
    point *np_list2 = malloc(num_of_points * sizeof(point));
    CalculateFaceTextureCoordinate(np_list2, num_of_points,
                                   _faceFeatureMine.face_rect, _faceFeatureMine.image_size,
                                   [_faceFeatureMine keyPointsRef]);
    
    delaunay *d = delaunay_build(num_of_points, np_list, 0, NULL, 0, NULL);
    
    GLfloat *textureCoordinates = (GLfloat *)malloc(d->ntriangles * 6 * sizeof(GLfloat));
    for (int i = 0; i < d->ntriangles; i++) {
        triangle t = d->triangles[i];
        int index = i * 6;
        for (int j = 0; j < 3; j ++) {
            point p = np_list[t.vids[j]];
            textureCoordinates[index + j*2] = p.x;
            textureCoordinates[index + j*2 + 1] = p.y;
        }
    }
    
    GLfloat *textureCoordinates2 = (GLfloat *)malloc(d->ntriangles * 6 * sizeof(GLfloat));
    for (int i = 0; i < d->ntriangles; i++) {
        triangle t = d->triangles[i];
        int index = i * 6;
        for (int j = 0; j < 3; j ++) {
            point p = np_list2[t.vids[j]];
            textureCoordinates2[index + j*2] = p.x;
            textureCoordinates2[index + j*2 + 1] = p.y;
        }
    }
    
    DLibFaceFeatures features_le = _faceFeatureModel.features_le;
    DLibFaceFeatures features_leb = _faceFeatureModel.features_leb;
    DLibFaceFeatures features_re = _faceFeatureModel.features_re;
    DLibFaceFeatures features_reb = _faceFeatureModel.features_reb;
    DLibFaceFeatures features_nu = _faceFeatureModel.features_nu;
    DLibFaceFeatures features_nd = _faceFeatureModel.features_nd;
    DLibFaceFeatures features_mu = _faceFeatureModel.features_mu;
    DLibFaceFeatures features_md = _faceFeatureModel.features_md;
    
    CGSize image_size = _faceFeatureModel.image_size;
    
    ApplyFeatures(&image_size, &features_le,   &_features_le,   DLibDefaultFaceStruct.VIDS_LE,  _shapeIntensity, np_list);
    ApplyFeatures(&image_size, &features_leb,  &_features_leb,  DLibDefaultFaceStruct.VIDS_LEB, _shapeIntensity, np_list);
    ApplyFeatures(&image_size, &features_re,   &_features_re,   DLibDefaultFaceStruct.VIDS_RE,  _shapeIntensity, np_list);
    ApplyFeatures(&image_size, &features_reb,  &_features_reb,  DLibDefaultFaceStruct.VIDS_REB, _shapeIntensity, np_list);
    ApplyFeatures(&image_size, &features_nu,   &_features_nu,   DLibDefaultFaceStruct.VIDS_NU,  _shapeIntensity, np_list);
    ApplyFeatures(&image_size, &features_nd,   &_features_nd,   DLibDefaultFaceStruct.VIDS_ND,  _shapeIntensity, np_list);
    ApplyFeatures(&image_size, &features_mu,   &_features_mu,   DLibDefaultFaceStruct.VIDS_MU,  _shapeIntensity, np_list);
    ApplyFeatures(&image_size, &features_md,   &_features_md,   DLibDefaultFaceStruct.VIDS_MD,  _shapeIntensity, np_list);
    
    GLfloat *imageVertices = (GLfloat *)malloc(d->ntriangles * 6 * sizeof(GLfloat));
    for (int i = 0; i < d->ntriangles; i++) {
        triangle t = d->triangles[i];
        int index = i * 6;
        for (int j = 0; j < 3; j ++) {
            int vid = t.vids[j];
            point p = np_list[vid];
            imageVertices[index + j*2] = p.x * 2.0 - 1.0;
            imageVertices[index + j*2 + 1] = p.y * 2.0 - 1.0;
        }
    }
    
    free(np_list);
    free(np_list2);
    
    [self renderToTextureWithVertices:imageVertices
                   textureCoordinates:textureCoordinates
                  textureCoordinates2:textureCoordinates2
                         elementCount:d->ntriangles];
    
    delaunay_destroy(d);
    free(imageVertices);
    free(textureCoordinates);
    free(textureCoordinates2);
    
    [self informTargetsAboutNewFrameAtTime:frameTime];
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
    // You can set up infinite update loops, so this helps to short circuit them
    if (hasReceivedFirstFrame && hasReceivedSecondFrame)
    {
        return;
    }
    
    BOOL updatedMovieFrameOppositeStillImage = NO;
    
    if (textureIndex == 0)
    {
        hasReceivedFirstFrame = YES;
        firstFrameTime = frameTime;
        if (secondFrameCheckDisabled)
        {
            hasReceivedSecondFrame = YES;
        }
        
        if (!CMTIME_IS_INDEFINITE(frameTime))
        {
            if CMTIME_IS_INDEFINITE(secondFrameTime)
            {
                updatedMovieFrameOppositeStillImage = YES;
            }
        }
    }
    else
    {
        hasReceivedSecondFrame = YES;
        secondFrameTime = frameTime;
        if (firstFrameCheckDisabled)
        {
            hasReceivedFirstFrame = YES;
        }
        
        if (!CMTIME_IS_INDEFINITE(frameTime))
        {
            if CMTIME_IS_INDEFINITE(firstFrameTime)
            {
                updatedMovieFrameOppositeStillImage = YES;
            }
        }
    }
    
    // || (hasReceivedFirstFrame && secondFrameCheckDisabled) || (hasReceivedSecondFrame && firstFrameCheckDisabled)
    if ((hasReceivedFirstFrame && hasReceivedSecondFrame) || updatedMovieFrameOppositeStillImage)
    {
        CMTime passOnFrameTime = (!CMTIME_IS_INDEFINITE(firstFrameTime)) ? firstFrameTime : secondFrameTime;
        [self newFrameReadyAtTime1:passOnFrameTime atIndex:0]; // Bugfix when trying to record: always use time from first input (unless indefinite, in which case use the second input)
        hasReceivedFirstFrame = NO;
        hasReceivedSecondFrame = NO;
    }
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices
                 textureCoordinates:(const GLfloat *)textureCoordinates
                textureCoordinates2:(const GLfloat *)textureCoordinates2
                       elementCount:(int)elementCount
{
    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    [GPUImageContext setActiveShaderProgram:filterProgram];
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }
    
    [self setUniformsForProgramAtIndex:0];
    
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    glUniform1i(filterInputTextureUniform, 2);
    
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, [secondInputFramebuffer texture]);
    glUniform1i(filterInputTextureUniform2, 3);
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, [[_maskImage framebufferForOutput] texture]);
    glUniform1i(maskUniform, 4);
    
    glUniform1f(mixUniform, _skinIntensity);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    glVertexAttribPointer(filterSecondTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates2);
    
    glDrawArrays(GL_TRIANGLES, 0, elementCount*3);
    
    [firstInputFramebuffer unlock];
    [secondInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture)
    {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
}

- (void)informTargetsAboutNewFrameAtTime:(CMTime)frameTime {
    [super informTargetsAboutNewFrameAtTime:frameTime];
}

typedef struct PNode {
    struct PNode *next;
    int val;
}PNode;

PNode *ListsMergeSort(PNode **lists, int num_of_list) {
    
    if (num_of_list <= 0) {
        return NULL;
    }
    
    if (num_of_list == 1) {
        return lists[0];
    }
    
    PNode *head_node = NULL;
    PNode *move_node = NULL;
    PNode **min_heap = malloc(num_of_list * sizeof(PNode **));
    
    for (int i = 0; i < num_of_list; i ++) {
        min_heap[i] = lists[i];
    }
    int num_of_nodes = num_of_list;
    
    MinHeapSort(min_heap, num_of_nodes);
    head_node = min_heap[0];
    move_node = min_heap[0];
    
    while (num_of_nodes > 1) {
        
        move_node->next = min_heap[0];
        move_node = min_heap[0];
        
        if (move_node->next != NULL) {
            min_heap[0] = move_node->next;
        }
        else {
            CutHead(min_heap, num_of_nodes);
            num_of_nodes--;
        }
        
        MinHeapSort(min_heap, num_of_nodes);
    }
    
    free(min_heap);
    return head_node;
}

void SwapNodeVal(PNode *n1, PNode *n2) {
    int tmp = n1->val;
    n1->val = n2->val;
    n2->val = tmp;
}

void MinHeapSort(PNode **nodes, int num_of_nodes) {
    for (int i = 0; i < num_of_nodes>>1; i ++) {
        PNode *n = nodes[i];
        PNode *left = nodes[2*i+1];
        if (n->val > left->val) {
            SwapNodeVal(n, left);
        }
        
        if (num_of_nodes > 2*(i+1)) {
            PNode *right = nodes[2*(i+1)];
            if (n->val > right->val) {
                SwapNodeVal(n, right);
            }
        }
    }
}

void CutHead(PNode **nodes, int num_of_nodes) {
    for (int i = 0; i < num_of_nodes-1; i++) {
        nodes[i] = nodes[i+1];
    }
}

@end
