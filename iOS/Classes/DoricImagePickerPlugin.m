#import "DoricImagePickerPlugin.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

typedef NS_ENUM(NSInteger, DoricImagePickerClassType) {
    UIImagePickerClassType, PHPickerClassType
};

typedef NS_ENUM(NSInteger, DoricImagePickerMIMEType) {
    DoricImagePickerMIMETypeJPG,
    DoricImagePickerMIMETypePNG,
    DoricImagePickerMIMETypeGIF,
    DoricImagePickerMIMETypeOther
};

@interface DoricPickerSaveImageToPathOperation : NSOperation
@property(strong, nonatomic) PHPickerResult *result;
@property(assign, nonatomic) NSNumber *maxHeight;
@property(assign, nonatomic) NSNumber *maxWidth;
@property(assign, nonatomic) NSNumber *desiredImageQuality;

- (instancetype)initWithResult:(PHPickerResult *)result
                     maxHeight:(NSNumber *)maxHeight
                      maxWidth:(NSNumber *)maxWidth
           desiredImageQuality:(NSNumber *)desiredImageQuality
                savedPathBlock:(void (^)(NSString *))savedPathBlock API_AVAILABLE(ios(14));

@end

typedef void (^GetSavedPath)(NSString *);


@interface GIFInfo : NSObject
@property(strong, nonatomic) NSArray<UIImage *> *images;
@property(assign, nonatomic) NSTimeInterval interval;

- (instancetype)initWithImages:(NSArray<UIImage *> *)images interval:(NSTimeInterval)interval;

@end

@implementation GIFInfo

- (instancetype)initWithImages:(NSArray<UIImage *> *)images interval:(NSTimeInterval)interval; {
    self = [super init];
    if (self) {
        self.images = images;
        self.interval = interval;
    }
    return self;
}

@end


@interface DoricImagePickerPlugin () <
        UIImagePickerControllerDelegate,
        UINavigationControllerDelegate,
        PHPickerViewControllerDelegate>
@property(nonatomic, strong) NSDictionary *params;
@property(nonatomic, strong) DoricPromise *promise;
@property(strong, nonatomic) PHPickerViewController *pickerViewController API_AVAILABLE(ios(14));
@property(strong, nonatomic) UIImagePickerController *imagePickerController;
@property(assign, nonatomic) int maxImagesAllowed;

+ (UIImage *)scaledImage:(UIImage *)image maxWidth:(NSNumber *)maxWidth maxHeight:(NSNumber *)maxHeight isMetadataAvailable:(BOOL)isMetadataAvailable;

+ (NSString *)saveImageWithMetaData:(NSDictionary *)metaData image:(UIImage *)image suffix:(NSString *)suffix type:(enum DoricImagePickerMIMEType)type imageQuality:(NSNumber *)imageQuality;

+ (NSString *)saveImageWithOriginalImageData:(NSData *)originalImageData image:(UIImage *)image maxWidth:(NSNumber *)maxWidth maxHeight:(NSNumber *)maxHeight imageQuality:(NSNumber *)imageQuality;

@end

static const uint8_t kFirstByteJPEG = 0xFF;
static const uint8_t kFirstBytePNG = 0x89;
static const uint8_t kFirstByteGIF = 0x47;


@implementation DoricPickerSaveImageToPathOperation {
    BOOL executing;
    BOOL finished;
    GetSavedPath getSavedPath;
}


- (instancetype)initWithResult:(PHPickerResult *)result
                     maxHeight:(NSNumber *)maxHeight
                      maxWidth:(NSNumber *)maxWidth
           desiredImageQuality:(NSNumber *)desiredImageQuality
                savedPathBlock:(GetSavedPath)savedPathBlock API_AVAILABLE(ios(14)) {
    if (self = [super init]) {
        if (result) {
            self.result = result;
            self.maxHeight = maxHeight;
            self.maxWidth = maxWidth;
            self.desiredImageQuality = desiredImageQuality;
            getSavedPath = savedPathBlock;
            executing = NO;
            finished = NO;
        } else {
            return nil;
        }
        return self;
    } else {
        return nil;
    }
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return executing;
}

- (BOOL)isFinished {
    return finished;
}

- (void)setFinished:(BOOL)isFinished {
    [self willChangeValueForKey:@"isFinished"];
    self->finished = isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)isExecuting {
    [self willChangeValueForKey:@"isExecuting"];
    self->executing = isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)completeOperationWithPath:(NSString *)savedPath {
    [self setExecuting:NO];
    [self setFinished:YES];
    getSavedPath(savedPath);
}

- (PHAsset *)getAssetFromPHPickerResult:(PHPickerResult *)result API_AVAILABLE(ios(14)) {
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[result.assetIdentifier]
                                                                  options:nil];
    return fetchResult.firstObject;
}

- (void)start {
    if ([self isCancelled]) {
        [self setFinished:YES];
        return;
    }
    if (@available(iOS 14, *)) {
        [self setExecuting:YES];
        [self.result.itemProvider
                loadObjectOfClass:[UIImage class]
                completionHandler:^(__kindof id <NSItemProviderReading> _Nullable image,
                        NSError *_Nullable error) {
                    if ([image isKindOfClass:[UIImage class]]) {
                        __block UIImage *localImage = image;
                        PHAsset *originalAsset =
                                [self getAssetFromPHPickerResult:self.result];

                        if (self.maxWidth != (id) [NSNull null] || self.maxHeight != (id) [NSNull null]) {
                            localImage = [DoricImagePickerPlugin scaledImage:localImage
                                                                    maxWidth:self.maxWidth
                                                                   maxHeight:self.maxHeight
                                                         isMetadataAvailable:originalAsset != nil];
                        }
                        __block NSString *savedPath;
                        if (!originalAsset) {
                            // Image picked without an original asset (e.g. User pick image without permission)

                            savedPath = [DoricImagePickerPlugin saveImageWithMetaData:nil
                                                                                image:localImage
                                                                               suffix:@".jpg"
                                                                                 type:DoricImagePickerMIMETypeJPG
                                                                         imageQuality:self.desiredImageQuality];
                            [self completeOperationWithPath:savedPath];
                        } else {
                            [[PHImageManager defaultManager]
                                    requestImageDataForAsset:originalAsset
                                                     options:nil
                                               resultHandler:^(
                                                       NSData *_Nullable imageData, NSString *_Nullable dataUTI,
                                                       UIImageOrientation orientation, NSDictionary *_Nullable info) {
                                                   // maxWidth and maxHeight are used only for GIF images.
                                                   savedPath = [DoricImagePickerPlugin
                                                           saveImageWithOriginalImageData:imageData
                                                                                    image:localImage
                                                                                 maxWidth:self.maxWidth
                                                                                maxHeight:self.maxHeight
                                                                             imageQuality:self.desiredImageQuality];
                                                   [self completeOperationWithPath:savedPath];
                                               }];
                        }
                    }
                }];
    } else {
        [self setFinished:YES];
    }
}

@end

@implementation DoricImagePickerPlugin
- (void)pickImage:(NSDictionary *)dic withPromise:(DoricPromise *)promise {
    self.params = dic;
    self.promise = promise;
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL useCamera = [dic[@"source"] integerValue] == 1;
        if (useCamera) {
            [self pickImageWithUIImagePicker];
        } else {
            if (@available(iOS 14, *)) {
                // PHPicker is used
                [self pickImageWithPHPicker:1];
            } else {
                // UIImagePicker is used
                [self pickImageWithUIImagePicker];
            }
        }
    });
}

- (void)pickMultiImage:(NSDictionary *)dic withPromise:(DoricPromise *)promise {
    self.params = dic;
    self.promise = promise;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 14, *)) {
            [self pickImageWithPHPicker:0];
        } else {
            [self pickImageWithUIImagePicker];
        }
    });
}

- (void)pickVideo:(NSDictionary *)dic withPromise:(DoricPromise *)promise {
    self.params = dic;
    self.promise = promise;
    dispatch_async(dispatch_get_main_queue(), ^{
        _imagePickerController = [[UIImagePickerController alloc] init];
        _imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
        _imagePickerController.delegate = self;
        _imagePickerController.mediaTypes = @[
                (NSString *) kUTTypeMovie, (NSString *) kUTTypeAVIMovie, (NSString *) kUTTypeVideo,
                (NSString *) kUTTypeMPEG4
        ];
        _imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;
        if ([dic[@"maxDuration"] isKindOfClass:[NSNumber class]]) {
            NSTimeInterval max = [dic[@"maxDuration"] doubleValue];
            _imagePickerController.videoMaximumDuration = max;
        }
        BOOL useCamera = [dic[@"source"] integerValue] == 1;
        if (useCamera) {
            [self checkCameraAuthorization];
        } else {
            [self checkPhotoAuthorization];
        }
    });
}

- (void)checkPhotoAuthorization {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusNotDetermined: {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (status == PHAuthorizationStatusAuthorized) {
                        [self showPhotoLibrary:UIImagePickerClassType];
                    } else {
                        [self.promise reject:@"Permission_NOT_GRANTED"];
                    }
                });
            }];
            break;
        }
        case PHAuthorizationStatusAuthorized:
            [self showPhotoLibrary:UIImagePickerClassType];
            break;
        case PHAuthorizationStatusDenied:
        case PHAuthorizationStatusRestricted:
        default:
            [self.promise reject:@"Permission_NOT_GRANTED"];
            break;
    }
}

- (void)pickImageWithPHPicker:(int)maxImagesAllowed API_AVAILABLE(ios(14)) {
    PHPickerConfiguration *config =
            [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
    config.selectionLimit = maxImagesAllowed;  // Setting to zero allow us to pick unlimited photos
    config.filter = [PHPickerFilter imagesFilter];

    _pickerViewController = [[PHPickerViewController alloc] initWithConfiguration:config];
    _pickerViewController.delegate = self;

    self.maxImagesAllowed = maxImagesAllowed;

    [self checkPhotoAuthorizationForAccessLevel];
}

- (void)checkPhotoAuthorizationForAccessLevel API_AVAILABLE(ios(14)) {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusNotDetermined: {
            [PHPhotoLibrary
                    requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                               handler:^(PHAuthorizationStatus status) {
                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                       if (status == PHAuthorizationStatusAuthorized) {
                                                           [self showPhotoLibrary:PHPickerClassType];
                                                       } else if (status == PHAuthorizationStatusLimited) {
                                                           [self showPhotoLibrary:PHPickerClassType];
                                                       } else {
                                                           [self.promise reject:@"Permission_NOT_GRANTED"];
                                                       }
                                                   });
                                               }];
            break;
        }
        case PHAuthorizationStatusAuthorized:
        case PHAuthorizationStatusLimited:
            [self showPhotoLibrary:PHPickerClassType];
            break;
        case PHAuthorizationStatusDenied:
        case PHAuthorizationStatusRestricted:
        default:
            [self.promise reject:@"Permission_NOT_GRANTED"];
            break;
    }
}

+ (DoricImagePickerMIMEType)getImageMIMETypeFromImageData:(NSData *)imageData {
    uint8_t firstByte;
    [imageData getBytes:&firstByte length:1];
    switch (firstByte) {
        case kFirstByteJPEG:
            return DoricImagePickerMIMETypeJPG;
        case kFirstBytePNG:
            return DoricImagePickerMIMETypePNG;
        case kFirstByteGIF:
            return DoricImagePickerMIMETypeGIF;
    }
    return DoricImagePickerMIMETypeOther;
}

+ (NSString *)imageTypeSuffixFromType:(DoricImagePickerMIMEType)type {
    switch (type) {
        case DoricImagePickerMIMETypeJPG:
            return @".jpg";
        case DoricImagePickerMIMETypePNG:
            return @".png";
        case DoricImagePickerMIMETypeGIF:
            return @".gif";
        default:
            return nil;
    }
}


+ (NSDictionary *)getMetaDataFromImageData:(NSData *)imageData {
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
    NSDictionary *metadata =
            (NSDictionary *) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CFRelease(source);
    return metadata;
}


+ (NSData *)imageFromImage:(NSData *)imageData withMetaData:(NSDictionary *)metadata {
    NSMutableData *targetData = [NSMutableData data];
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
    if (source == NULL) {
        return nil;
    }
    CGImageDestinationRef destination = NULL;
    CFStringRef sourceType = CGImageSourceGetType(source);
    if (sourceType != NULL) {
        destination =
                CGImageDestinationCreateWithData((__bridge CFMutableDataRef) targetData, sourceType, 1, nil);
    }
    if (destination == NULL) {
        CFRelease(source);
        return nil;
    }
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
    CGImageDestinationFinalize(destination);
    CFRelease(source);
    CFRelease(destination);
    return targetData;
}


+ (NSData *)convertImage:(UIImage *)image
               usingType:(DoricImagePickerMIMEType)type
                 quality:(nullable NSNumber *)quality {
    if (quality && type != DoricImagePickerMIMETypeJPG) {
        NSLog(@"image_picker: compressing is not supported for type %@. Returning the image with "
              @"original quality",
                [self imageTypeSuffixFromType:type]);
    }

    switch (type) {
        case DoricImagePickerMIMETypeJPG: {
            CGFloat qualityFloat = (quality != nil) ? quality.floatValue : 1;
            return UIImageJPEGRepresentation(image, qualityFloat);
        }
        case DoricImagePickerMIMETypePNG:
            return UIImagePNGRepresentation(image);
        default: {
            // converts to JPEG by default.
            CGFloat qualityFloat = (quality != nil) ? quality.floatValue : 1;
            return UIImageJPEGRepresentation(image, qualityFloat);
        }
    }
}


- (void)pickImageWithUIImagePicker {
    _imagePickerController = [[UIImagePickerController alloc] init];
    _imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    _imagePickerController.delegate = self;
    _imagePickerController.mediaTypes = @[(NSString *) kUTTypeImage];
    self.maxImagesAllowed = 1;
    BOOL useCamera = [self.params[@"source"] integerValue] == 1;
    if (useCamera) {
        [self checkCameraAuthorization];
    } else {
        [self checkPhotoAuthorization];
    }
}

- (void)checkCameraAuthorization {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    switch (status) {
        case AVAuthorizationStatusAuthorized:
            [self showCamera];
            break;
        case AVAuthorizationStatusNotDetermined: {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                     completionHandler:^(BOOL granted) {
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             if (granted) {
                                                 [self showCamera];
                                             } else {
                                                 [self.promise reject:@"Permission_NOT_GRANTED"];
                                             }
                                         });
                                     }];
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
        default:
            [self.promise reject:@"Permission_NOT_GRANTED"];
            break;
    }
}

- (UIImagePickerControllerCameraDevice)getCameraDeviceFromArguments:(NSDictionary *)arguments {
    return ([arguments[@"cameraDevice"] isEqualToString:@"front"]) ? UIImagePickerControllerCameraDeviceFront
            : UIImagePickerControllerCameraDeviceRear;
}

- (void)showCamera {
    @synchronized (self) {
        if (_imagePickerController.beingPresented) {
            return;
        }
    }
    UIImagePickerControllerCameraDevice device = [self getCameraDeviceFromArguments:self.params];
    // Camera is not available on simulators
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] &&
            [UIImagePickerController isCameraDeviceAvailable:device]) {
        _imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        _imagePickerController.cameraDevice = device;
        [self.doricContext.vc presentViewController:_imagePickerController
                                           animated:YES
                                         completion:nil];
    } else {
        [self.promise reject:@"NO_AVAILABLE_CAMERA"];
    }
}

- (void)showPhotoLibrary:(DoricImagePickerClassType)imagePickerClassType {
    // No need to check if SourceType is available. It always is.
    switch (imagePickerClassType) {
        case PHPickerClassType:
            [self.doricContext.vc presentViewController:_pickerViewController
                                               animated:YES
                                             completion:nil];
            break;
        case UIImagePickerClassType: {
            [self.doricContext.vc presentViewController:_imagePickerController
                                               animated:YES
                                             completion:nil];
            break;
        }
    }
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self.promise resolve:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    NSURL *videoURL = info[UIImagePickerControllerMediaURL];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (videoURL != nil) {
        if (@available(iOS 13.0, *)) {
            NSString *fileName = [videoURL lastPathComponent];
            NSURL *destination =
                    [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];

            if ([[NSFileManager defaultManager] isReadableFileAtPath:[videoURL path]]) {
                NSError *error;
                if (![[videoURL path] isEqualToString:[destination path]]) {
                    [[NSFileManager defaultManager] copyItemAtURL:videoURL toURL:destination error:&error];

                    if (error) {
                        [self.promise reject:@"CANNOT_CACHE_FILE"];
                        return;
                    }
                }
                videoURL = destination;
            }
        }
        [self.promise resolve:@{@"filePath": videoURL.path}];
    } else {
        UIImage *image = info[UIImagePickerControllerEditedImage];
        if (image == nil) {
            image = info[UIImagePickerControllerOriginalImage];
        }
        NSNumber *maxWidth = self.params[@"maxWidth"];
        NSNumber *maxHeight = self.params[@"maxHeight"];
        NSNumber *imageQuality = self.params[@"imageQuality"];
        NSNumber *desiredImageQuality = [self getDesiredImageQuality:imageQuality];

        PHAsset *originalAsset = [self getAssetFromImagePickerInfo:info];

        if (maxWidth || maxHeight) {
            image = [DoricImagePickerPlugin scaledImage:image
                                               maxWidth:maxWidth
                                              maxHeight:maxHeight
                                    isMetadataAvailable:YES];
        }

        if (!originalAsset) {
            // Image picked without an original asset (e.g. User took a photo directly)
            [self saveImageWithPickerInfo:info image:image imageQuality:desiredImageQuality];
        } else {
            [[PHImageManager defaultManager]
                    requestImageDataForAsset:originalAsset
                                     options:nil
                               resultHandler:^(NSData *_Nullable imageData, NSString *_Nullable dataUTI,
                                       UIImageOrientation orientation, NSDictionary *_Nullable info) {
                                   // maxWidth and maxHeight are used only for GIF images.
                                   NSString *path = [DoricImagePickerPlugin saveImageWithOriginalImageData:imageData
                                                                                                     image:image
                                                                                                  maxWidth:maxWidth
                                                                                                 maxHeight:maxHeight
                                                                                              imageQuality:desiredImageQuality];
                                   [self.promise resolve:@{@"filePath": path}];
                               }];
        }
    }
}


+ (NSString *)saveImageWithOriginalImageData:(NSData *)originalImageData
                                       image:(UIImage *)image
                                    maxWidth:(NSNumber *)maxWidth
                                   maxHeight:(NSNumber *)maxHeight
                                imageQuality:(NSNumber *)imageQuality {
    NSString *suffix = @".jpg";
    DoricImagePickerMIMEType type = DoricImagePickerMIMETypeJPG;
    NSDictionary *metaData = nil;
    // Getting the image type from the original image data if necessary.
    if (originalImageData) {
        type = [self getImageMIMETypeFromImageData:originalImageData];
        suffix = [self imageTypeSuffixFromType:type] ?: suffix;
        metaData = [DoricImagePickerPlugin getMetaDataFromImageData:originalImageData];
    }
    if (type == DoricImagePickerMIMETypeGIF) {
        GIFInfo *gifInfo = [self scaledGIFImage:originalImageData
                                       maxWidth:maxWidth
                                      maxHeight:maxHeight];

        return [self saveImageWithMetaData:metaData gifInfo:gifInfo suffix:suffix];
    } else {
        return [self saveImageWithMetaData:metaData
                                     image:image
                                    suffix:suffix
                                      type:type
                              imageQuality:imageQuality];
    }
}

+ (GIFInfo *)scaledGIFImage:(NSData *)data
                   maxWidth:(NSNumber *)maxWidth
                  maxHeight:(NSNumber *)maxHeight {
    NSMutableDictionary<NSString *, id> *options = [NSMutableDictionary dictionary];
    options[(NSString *) kCGImageSourceShouldCache] = @(YES);
    options[(NSString *) kCGImageSourceTypeIdentifierHint] = (NSString *) kUTTypeGIF;

    CGImageSourceRef imageSource =
            CGImageSourceCreateWithData((__bridge CFDataRef) data, (__bridge CFDictionaryRef) options);

    size_t numberOfFrames = CGImageSourceGetCount(imageSource);
    NSMutableArray<UIImage *> *images = [NSMutableArray arrayWithCapacity:numberOfFrames];

    NSTimeInterval interval = 0.0;
    for (size_t index = 0; index < numberOfFrames; index++) {
        CGImageRef imageRef =
                CGImageSourceCreateImageAtIndex(imageSource, index, (__bridge CFDictionaryRef) options);

        NSDictionary *properties = (NSDictionary *) CFBridgingRelease(
                CGImageSourceCopyPropertiesAtIndex(imageSource, index, NULL));
        NSDictionary *gifProperties = properties[(NSString *) kCGImagePropertyGIFDictionary];

        NSNumber *delay = gifProperties[(NSString *) kCGImagePropertyGIFUnclampedDelayTime];
        if (delay == nil) {
            delay = gifProperties[(NSString *) kCGImagePropertyGIFDelayTime];
        }

        if (interval == 0.0) {
            interval = [delay doubleValue];
        }

        UIImage *image = [UIImage imageWithCGImage:imageRef scale:1.0 orientation:UIImageOrientationUp];
        image = [self scaledImage:image maxWidth:maxWidth maxHeight:maxHeight isMetadataAvailable:YES];

        [images addObject:image];

        CGImageRelease(imageRef);
    }

    CFRelease(imageSource);

    GIFInfo *info = [[GIFInfo alloc] initWithImages:images interval:interval];

    return info;
}

- (void)saveImageWithPickerInfo:(NSDictionary *)info
                          image:(UIImage *)image
                   imageQuality:(NSNumber *)imageQuality {

    NSDictionary *metaData = info[UIImagePickerControllerMediaMetadata];
    NSString *savedPath = [DoricImagePickerPlugin saveImageWithMetaData:metaData
                                                                  image:image
                                                                 suffix:@".jpg"
                                                                   type:DoricImagePickerMIMETypeJPG
                                                           imageQuality:imageQuality];
    [self handleSavedPathList:@[savedPath]];
}

- (void)handleSavedPathList:(NSArray *)pathList {
    if ((self.maxImagesAllowed == 1)) {
        [self.promise resolve:@{@"filePath": pathList.firstObject}];
    } else {
        [self.promise resolve:[pathList map:^id(NSString *obj) {
            return @{@"filePath": obj};
        }]];
    }
}

- (PHAsset *)getAssetFromImagePickerInfo:(NSDictionary *)info {
    if (@available(iOS 11, *)) {
        return info[UIImagePickerControllerPHAsset];
    }
    NSURL *referenceURL = info[UIImagePickerControllerReferenceURL];
    if (!referenceURL) {
        return nil;
    }
    PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithALAssetURLs:@[referenceURL]
                                                                   options:nil];
    return result.firstObject;
}


+ (UIImage *)scaledImage:(UIImage *)image
                maxWidth:(NSNumber *)maxWidth
               maxHeight:(NSNumber *)maxHeight
     isMetadataAvailable:(BOOL)isMetadataAvailable {
    double originalWidth = image.size.width;
    double originalHeight = image.size.height;

    bool hasMaxWidth = maxWidth != (id) [NSNull null];
    bool hasMaxHeight = maxHeight != (id) [NSNull null];

    double width = hasMaxWidth ? MIN([maxWidth doubleValue], originalWidth) : originalWidth;
    double height = hasMaxHeight ? MIN([maxHeight doubleValue], originalHeight) : originalHeight;

    bool shouldDownscaleWidth = hasMaxWidth && [maxWidth doubleValue] < originalWidth;
    bool shouldDownscaleHeight = hasMaxHeight && [maxHeight doubleValue] < originalHeight;
    bool shouldDownscale = shouldDownscaleWidth || shouldDownscaleHeight;

    if (shouldDownscale) {
        double downscaledWidth = floor((height / originalHeight) * originalWidth);
        double downscaledHeight = floor((width / originalWidth) * originalHeight);

        if (width < height) {
            if (!hasMaxWidth) {
                width = downscaledWidth;
            } else {
                height = downscaledHeight;
            }
        } else if (height < width) {
            if (!hasMaxHeight) {
                height = downscaledHeight;
            } else {
                width = downscaledWidth;
            }
        } else {
            if (originalWidth < originalHeight) {
                width = downscaledWidth;
            } else if (originalHeight < originalWidth) {
                height = downscaledHeight;
            }
        }
    }

    if (!isMetadataAvailable) {
        UIImage *imageToScale = [UIImage imageWithCGImage:image.CGImage
                                                    scale:1
                                              orientation:image.imageOrientation];

        UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
        [imageToScale drawInRect:CGRectMake(0, 0, width, height)];

        UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return scaledImage;
    }

    // Scaling the image always rotate itself based on the current imageOrientation of the original
    // Image. Set to orientationUp for the orignal image before scaling, so the scaled image doesn't
    // mess up with the pixels.
    UIImage *imageToScale = [UIImage imageWithCGImage:image.CGImage
                                                scale:1
                                          orientation:UIImageOrientationUp];

    // The image orientation is manually set to UIImageOrientationUp which swapped the aspect ratio in
    // some scenarios. For example, when the original image has orientation left, the horizontal
    // pixels should be scaled to `width` and the vertical pixels should be scaled to `height`. After
    // setting the orientation to up, we end up scaling the horizontal pixels to `height` and vertical
    // to `width`. Below swap will solve this issue.
    if ([image imageOrientation] == UIImageOrientationLeft ||
            [image imageOrientation] == UIImageOrientationRight ||
            [image imageOrientation] == UIImageOrientationLeftMirrored ||
            [image imageOrientation] == UIImageOrientationRightMirrored) {
        double temp = width;
        width = height;
        height = temp;
    }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
    [imageToScale drawInRect:CGRectMake(0, 0, width, height)];

    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

- (NSNumber *)getDesiredImageQuality:(NSNumber *)imageQuality {
    if (![imageQuality isKindOfClass:[NSNumber class]]) {
        imageQuality = @1;
    } else if (imageQuality.intValue < 0 || imageQuality.intValue > 100) {
        imageQuality = @1;
    } else {
        imageQuality = @([imageQuality floatValue] / 100);
    }
    return imageQuality;
}

+ (NSString *)saveImageWithMetaData:(NSDictionary *)metaData
                            gifInfo:(GIFInfo *)gifInfo
                             suffix:(NSString *)suffix {
    NSString *path = [self temporaryFilePath:suffix];
    return [self saveImageWithMetaData:metaData gifInfo:gifInfo path:path];
}

+ (NSString *)saveImageWithMetaData:(NSDictionary *)metaData
                              image:(UIImage *)image
                             suffix:(NSString *)suffix
                               type:(DoricImagePickerMIMEType)type
                       imageQuality:(NSNumber *)imageQuality {
    NSData *data = [self convertImage:image
                            usingType:type
                              quality:imageQuality];
    if (metaData) {
        NSData *updatedData = [self imageFromImage:data withMetaData:metaData];
        // If updating the metadata fails, just save the original.
        if (updatedData) {
            data = updatedData;
        }
    }

    return [self createFile:data suffix:suffix];
}

+ (NSString *)saveImageWithMetaData:(NSDictionary *)metaData
                            gifInfo:(GIFInfo *)gifInfo
                               path:(NSString *)path {
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(
            (__bridge CFURLRef) [NSURL fileURLWithPath:path], kUTTypeGIF, gifInfo.images.count, NULL);

    NSDictionary *frameProperties = @{
            (__bridge NSString *) kCGImagePropertyGIFDictionary: @{
                    (__bridge NSString *) kCGImagePropertyGIFDelayTime: @(gifInfo.interval),
            },
    };

    NSMutableDictionary *gifMetaProperties = [NSMutableDictionary dictionaryWithDictionary:metaData];
    NSMutableDictionary *gifProperties =
            (NSMutableDictionary *) gifMetaProperties[(NSString *) kCGImagePropertyGIFDictionary];
    if (gifMetaProperties == nil) {
        gifProperties = [NSMutableDictionary dictionary];
    }

    gifProperties[(__bridge NSString *) kCGImagePropertyGIFLoopCount] = @0;

    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef) gifMetaProperties);

    for (NSUInteger index = 0; index < gifInfo.images.count; index++) {
        UIImage *image = gifInfo.images[index];
        CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef) frameProperties);
    }

    CGImageDestinationFinalize(destination);
    CFRelease(destination);

    return path;
}

+ (NSString *)temporaryFilePath:(NSString *)suffix {
    NSString *fileExtension = [@"image_picker_%@" stringByAppendingString:suffix];
    NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString *tmpFile = [NSString stringWithFormat:fileExtension, guid];
    NSString *tmpDirectory = NSTemporaryDirectory();
    NSString *tmpPath = [tmpDirectory stringByAppendingPathComponent:tmpFile];
    return tmpPath;
}

+ (NSString *)createFile:(NSData *)data suffix:(NSString *)suffix {
    NSString *tmpPath = [self temporaryFilePath:suffix];
    if ([[NSFileManager defaultManager] createFileAtPath:tmpPath contents:data attributes:nil]) {
        return tmpPath;
    } else {
        nil;
    }
    return tmpPath;
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    dispatch_queue_t backgroundQueue =
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(backgroundQueue, ^{
        if (results.count == 0) {
            [self.promise resolve:nil];
            return;
        }
        NSNumber *maxWidth = self.params[@"maxWidth"];
        NSNumber *maxHeight = self.params[@"maxHeight"];
        NSNumber *imageQuality = self.params[@"imageQuality"];
        NSNumber *desiredImageQuality = [self getDesiredImageQuality:imageQuality];
        NSOperationQueue *operationQueue = [NSOperationQueue new];
        NSMutableArray *pathList = [NSMutableArray new];

        for (NSUInteger i = 0; i < results.count; i++) {
            PHPickerResult *result = results[i];
            DoricPickerSaveImageToPathOperation *operation =
                    [[DoricPickerSaveImageToPathOperation alloc] initWithResult:result
                                                                      maxHeight:maxHeight
                                                                       maxWidth:maxWidth
                                                            desiredImageQuality:desiredImageQuality
                                                                 savedPathBlock:^(NSString *savedPath) {
                                                                     pathList[i] = savedPath;
                                                                 }];
            [operationQueue addOperation:operation];
        }
        [operationQueue waitUntilAllOperationsAreFinished];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleSavedPathList:pathList];
        });
    });
}
@end