//
//  SBAPermissionsManager.h
//  BridgeAppSDK
//
//  Copyright © 2016 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
 
#import "SBAPermissionsManager.h"
#import <BridgeAppSDK/BridgeAppSDK-Swift.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

static NSString * const SBAPermissionsManagerErrorDomain = @"SBAPermissionsManagerErrorDomain";

static NSString * const SBARemindersOnKey = @"SBARemindersOnKey";

NSBundle *SBABundle() {
    static NSBundle *__bundle;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __bundle = [NSBundle bundleForClass:[SBAPermissionsManager class]];
    });
    
    return __bundle;
}

typedef NS_ENUM(NSUInteger, SBAPermissionsErrorCode) {
    SBAPermissionsErrorCodeAccessDenied = -100,
};

@interface SBAPermissionsManager () <CLLocationManagerDelegate>

@property (nonatomic, readwrite) HKHealthStore * healthStore;
@property (nonatomic, readwrite) CLLocationManager *locationManager;
@property (nonatomic, readwrite) CMMotionActivityManager *motionActivityManager;

@property (nonatomic) SBAPermissionStatus coreMotionPermissionStatus;

@property (nonatomic, copy) NSArray *healthKitCharacteristicTypesToRead;
@property (nonatomic, copy) NSArray *healthKitTypesToRead;
@property (nonatomic, copy) NSArray *healthKitTypesToWrite;

@property (nonatomic, copy) SBAPermissionsBlock locationCompletionBlock;
@property (nonatomic, copy) SBAPermissionsBlock notificationsCompletionBlock;

@end


@implementation SBAPermissionsManager

+ (instancetype)sharedManager {
    static id __instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __instance = [[self alloc] init];
    });
    return __instance;
}

#pragma mark - memory allocation

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _locationManager.delegate = nil;
}

- (HKHealthStore *)healthStore {
    if (_healthStore == nil && [HKHealthStore isHealthDataAvailable]) {
        _healthStore = [[HKHealthStore alloc] init];
    }
    return _healthStore;
}

- (CLLocationManager *)locationManager {
    if (_locationManager == nil) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
    }
    return _locationManager;
}

- (CMMotionActivityManager *)motionActivityManager {
    if (_motionActivityManager == nil) {
        _motionActivityManager = [[CMMotionActivityManager alloc] init];
    }
    return _motionActivityManager;
}

- (void)setupHealthKitCharacteristicTypesToRead:(NSArray *)characteristicTypesToRead
                   healthKitQuantityTypesToRead:(NSArray *)quantityTypesToRead
                  healthKitQuantityTypesToWrite:(NSArray *)QuantityTypesToWrite {
    
    self.healthKitCharacteristicTypesToRead = characteristicTypesToRead;
    self.healthKitTypesToRead = quantityTypesToRead;
    self.healthKitTypesToWrite = QuantityTypesToWrite;
}

#pragma mark - public methods

- (BOOL)isPermissionsGrantedForType:(SBAPermissionsType)type {
    switch (type) {
            
        case SBAPermissionsTypeNone:
            return YES;
            
        case SBAPermissionsTypeHealthKit:
            return [self isPermissionsGrantedForHealthKit];
            
        case SBAPermissionsTypeLocation:
            return [self isPermissionsGrantedForLocation];
            
        case SBAPermissionsTypeLocalNotifications:
            return [self isPermissionsGrantedForNotifications];
            
        case SBAPermissionsTypeCoremotion:
            return [self isPermissionsGrantedForCoreMotion];
            
        case SBAPermissionsTypeMicrophone:
            return [self isPermissionsGrantedForMicrophone];

        case SBAPermissionsTypeCamera:
            return [self isPermissionsGrantedForCamera];

        case SBAPermissionsTypePhotoLibrary:
            return [self isPermissionsGrantedForPhotoLibrary];
            
        default:
            return NO;
    }
}

- (void)requestPermissionForType:(SBAPermissionsType)type
                  withCompletion:(SBAPermissionsBlock)completion {
    switch (type) {
            
        case SBAPermissionsTypeHealthKit:
            [self requestForPermissionHealthKitWithCompletion:completion];
            break;
            
        case SBAPermissionsTypeLocation:
            [self requestForPermissionLocationWithCompletion:completion];
            break;
            
        case SBAPermissionsTypeLocalNotifications:
            [self requestForPermissionNotificationsWithCompletion:completion];
            break;
            
        case SBAPermissionsTypeCoremotion:
            [self requestForPermissionCoreMotionWithCompletion:completion];
            break;
            
        case SBAPermissionsTypeMicrophone:
            [self requestForPermissionMicrophoneWithCompletion:completion];
            break;
            
        case SBAPermissionsTypeCamera:
            [self requestForPermissionCameraWithCompletion:completion];
            break;
            
        case SBAPermissionsTypePhotoLibrary:
            [self requestForPermissionPhotoLibraryWithCompletion:completion];
            break;
            
        default:
            NSAssert(false, @"Unsupported Permission type");
            if (completion) {
                completion(NO, [SBAPermissionsManager permissionDeniedErrorForType:type]);
            }
            break;
    }
}

- (NSString *)permissionTitleForType:(SBAPermissionsType)type {
    switch (type) {
            
        case SBAPermissionsTypeHealthKit:
            return [Localization localizedString:@"SBA_HEALTHKIT_PERMISSIONS_TITLE"];
            
        case SBAPermissionsTypeLocation:
            return [Localization localizedString:@"SBA_LOCATION_PERMISSIONS_TITLE"];

        case SBAPermissionsTypeCoremotion:
            return [Localization localizedString:@"SBA_COREMOTION_PERMISSIONS_TITLE"];

        case SBAPermissionsTypeLocalNotifications:
            return [Localization localizedString:@"SBA_REMINDER_PERMISSIONS_TITLE"];

        case SBAPermissionsTypeMicrophone:
            return [Localization localizedString:@"SBA_MICROPHONE_PERMISSIONS_TITLE"];
            
        case SBAPermissionsTypeCamera:
            return [Localization localizedString:@"SBA_CAMERA_PERMISSIONS_TITLE"];
            
        case SBAPermissionsTypePhotoLibrary:
            return [Localization localizedString:@"SBA_PHOTOLIBRARY_PERMISSIONS_TITLE"];
            
        default:
            return @"";
    }
}

- (NSString *)permissionDescriptionForType:(SBAPermissionsType)type {
    switch (type) {
        case SBAPermissionsTypeHealthKit:
            return [Localization localizedString:@"SBA_HEALTHKIT_PERMISSIONS_DESCRIPTION"];
        case SBAPermissionsTypeLocalNotifications:
            return [Localization localizedString:@"SBA_REMINDER_PERMISSIONS_DESCRIPTION"];
        case SBAPermissionsTypeLocation:
            return [self bundlePermissionDescriptionForKey: @"NSLocationWhenInUseUsageDescription" defaultValue:@"Using your GPS enables the app to accurately determine distances travelled. Your actual location will never be shared."];
        case SBAPermissionsTypeCoremotion:
            return [self bundlePermissionDescriptionForKey: @"NSMotionUsageDescription" defaultValue:@"Using the motion co-processor allows the app to determine your activity, helping the study better understand how activity level may influence disease."];
        case SBAPermissionsTypeMicrophone:
            return [self bundlePermissionDescriptionForKey: @"NSMicrophoneUsageDescription" defaultValue:@"Access to microphone is required for your Voice Recording Activity."];
        case SBAPermissionsTypePhotoLibrary:
            return [self bundlePermissionDescriptionForKey: @"NSPhotoLibraryUsageDescription" defaultValue:@"Photo Library"];
        case SBAPermissionsTypeCamera:
        default:
            return [NSString stringWithFormat:@"Unknown permission type: %u", (unsigned int)type];
    }
}

- (NSString *)bundlePermissionDescriptionForKey:(NSString *)key defaultValue:(NSString*)defaultValue {
    NSDictionary *info = [[NSBundle mainBundle] localizedInfoDictionary] ?: [[NSBundle mainBundle] infoDictionary];
    NSString *str = info[key];
    if (![str isKindOfClass:[NSString class]]) {
        NSAssert1(NO, @"Missing required main bundle info.plist key %@", key);
        str = defaultValue;
    }
    return str;
}

+ (NSError *)permissionDeniedErrorForType:(SBAPermissionsType)type
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    NSString *message = nil;
    
    switch (type) {
        case SBAPermissionsTypeHealthKit:
            message = [NSString localizedStringWithFormat:[Localization localizedString:@"SBA_HEALTHKIT_PERMISSIONS_ERROR"], appName];
            break;
        case SBAPermissionsTypeLocalNotifications:
            message = [Localization localizedString:@"SBA_REMINDER_PERMISSIONS_ERROR"];
            break;
        case SBAPermissionsTypeLocation:
            message = [Localization localizedString:@"SBA_LOCATION_PERMISSIONS_ERROR"];
            break;
        case SBAPermissionsTypeCoremotion:
            message = [Localization localizedString:@"SBA_COREMOTION_PERMISSIONS_ERROR"];
            break;
        case SBAPermissionsTypeMicrophone:
            message = [Localization localizedString:@"SBA_MICROPHONE_PERMISSIONS_ERROR"];
            break;
        case SBAPermissionsTypeCamera:
            message = [Localization localizedString:@"SBA_CAMERA_PERMISSIONS_ERROR"];
            break;
        case SBAPermissionsTypePhotoLibrary:
            message = [Localization localizedString:@"SBA_PHOTOLIBRARY_PERMISSIONS_ERROR"];
            break;
        default:
            message = [Localization localizedString:@"SBA_GENERAL_PERMISSIONS_ERROR"];
            break;
    }

    NSError *error = [NSError errorWithDomain:SBAPermissionsManagerErrorDomain
                                         code:SBAPermissionsErrorCodeAccessDenied
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
    
    return error;
}

//---------------------------------------------------------------
#pragma mark - HealthKit
//---------------------------------------------------------------

NSString *const kHKQuantityTypeKey          = @"HKQuantityType";
NSString *const kHKCategoryTypeKey          = @"HKCategoryType";
NSString *const kHKCharacteristicTypeKey    = @"HKCharacteristicType";
NSString *const kHKCorrelationTypeKey       = @"HKCorrelationType";
NSString *const kHKWorkoutTypeKey           = @"HKWorkoutType";

- (BOOL)isPermissionsGrantedForHealthKit {
    HKCharacteristicType *dateOfBirth = [HKCharacteristicType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth];
    HKAuthorizationStatus status = [self.healthStore authorizationStatusForType:dateOfBirth];
    return (status == HKAuthorizationStatusSharingAuthorized);
}

- (void)requestForPermissionHealthKitWithCompletion:(SBAPermissionsBlock)completion {
    
    //------READ TYPES--------
    NSMutableArray *dataTypesToRead = [NSMutableArray new];
    
    // Add Characteristic types
    for (NSString *typeIdentifier in self.healthKitCharacteristicTypesToRead) {
        [dataTypesToRead addObject:[HKCharacteristicType characteristicTypeForIdentifier:typeIdentifier]];
    }
    
    //Add other quantity types
    for (id typeIdentifier in self.healthKitTypesToRead) {
        if ([typeIdentifier isKindOfClass:[NSString class]]) {
            [dataTypesToRead addObject:[HKQuantityType quantityTypeForIdentifier:typeIdentifier]];
        }
        else if ([typeIdentifier isKindOfClass:[NSDictionary class]])
        {
            if (typeIdentifier[kHKWorkoutTypeKey])
            {
                [dataTypesToRead addObject:[HKObjectType workoutType]];
            }
            else
            {
                [dataTypesToRead addObject:[self hkObjectTypeFromDictionary:typeIdentifier]];
            }
        }
    }
    
    //-------WRITE TYPES--------
    NSMutableArray *dataTypesToWrite = [NSMutableArray new];
    
    for (id typeIdentifier in self.healthKitTypesToWrite) {
        if ([typeIdentifier isKindOfClass:[NSString class]]) {
            [dataTypesToWrite addObject:[HKQuantityType quantityTypeForIdentifier:typeIdentifier]];
        }
        else if ([typeIdentifier isKindOfClass:[NSDictionary class]])
        {
            [dataTypesToWrite addObject:[self hkObjectTypeFromDictionary:typeIdentifier]];
        }
    }
    
    [self.healthStore requestAuthorizationToShareTypes:[NSSet setWithArray:dataTypesToWrite] readTypes:[NSSet setWithArray:dataTypesToRead] completion:^(BOOL success, NSError *error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, error);
            });
        }
    }];
}

- (HKObjectType*) hkObjectTypeFromDictionary: (NSDictionary*) dictionary
{
    NSString * key = [[dictionary allKeys] firstObject];
    HKObjectType * retValue;
    if ([key isEqualToString:kHKQuantityTypeKey])
    {
        retValue = [HKQuantityType quantityTypeForIdentifier:dictionary[key]];
    }
    else if ([key isEqualToString:kHKCategoryTypeKey])
    {
        retValue = [HKCategoryType categoryTypeForIdentifier:dictionary[key]];
    }
    else if ([key isEqualToString:kHKCharacteristicTypeKey])
    {
        retValue = [HKCharacteristicType characteristicTypeForIdentifier:dictionary[key]];
    }
    else if ([key isEqualToString:kHKCorrelationTypeKey])
    {
        retValue = [HKCorrelationType correlationTypeForIdentifier:dictionary[key]];
    }
    return retValue;
}


//---------------------------------------------------------------
#pragma mark - Location
//---------------------------------------------------------------

- (BOOL)isPermissionsGrantedForLocation {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#else
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    return  (status == kCLAuthorizationStatusAuthorizedWhenInUse) ||
            (status == kCLAuthorizationStatusAuthorizedAlways);
#endif
}

- (void)requestForPermissionLocationWithCompletion:(SBAPermissionsBlock)completion {

    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];

    if (status == kCLAuthorizationStatusNotDetermined) {
        // Add pointer to the completion block and fire off request to accept permission
        self.locationCompletionBlock = completion;
        [self.locationManager requestAlwaysAuthorization];
        [self.locationManager requestWhenInUseAuthorization];
    }
    else {
        // If the status is not determined, then it has not been requested otherwise,
        // Do not need to ask again. Just call completion.
        if (completion) {
            completion(NO, [SBAPermissionsManager permissionDeniedErrorForType:SBAPermissionsTypeLocation]);
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *) __unused error {
    [manager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *) __unused manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        {
            [self.locationManager stopUpdatingLocation];
            if (self.locationCompletionBlock) {
                self.locationCompletionBlock(YES, nil);
            }
        }
            break;
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted: {
            [self.locationManager stopUpdatingLocation];
            if (self.locationCompletionBlock) {
                self.locationCompletionBlock(NO, [SBAPermissionsManager permissionDeniedErrorForType:SBAPermissionsTypeLocation]);
            }
            break;
        }
    }
    
    self.locationCompletionBlock = nil;
}


//---------------------------------------------------------------
#pragma mark - Remote notifications
//---------------------------------------------------------------

- (BOOL)isPermissionsGrantedForNotifications {
    return [[UIApplication sharedApplication] currentUserNotificationSettings].types != 0;
}

- (void)requestForPermissionNotificationsWithCompletion:(SBAPermissionsBlock)completion {

    if ([[UIApplication sharedApplication] currentUserNotificationSettings].types == UIUserNotificationTypeNone) {
        self.notificationsCompletionBlock = completion;

        UIUserNotificationType types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;        
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types
                                                                                 categories:nil];

        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[NSUserDefaults standardUserDefaults] synchronize];
        // In the case of notifications, callbacks are used to fire the completion block.
        // Callbacks are delivered to appDidRegisterForRemoteNotifications:
    }
    else {
        // Request previously granted
        if (completion) {
            completion(YES, nil);
        }
    }
}

- (void)appDidRegisterForRemoteNotifications: (UIUserNotificationSettings *)settings
{
    if (settings.types != 0) {
        
        // TODO: syoung 09/08/2016 Revisit permissions notification handling
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SBARemindersOnKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if (self.notificationsCompletionBlock) {
            self.notificationsCompletionBlock(YES, nil);
        }
    }
	else {
        
        if (self.notificationsCompletionBlock) {
            self.notificationsCompletionBlock(NO, [SBAPermissionsManager permissionDeniedErrorForType:SBAPermissionsTypeLocalNotifications]);
        }
    }
    self.notificationsCompletionBlock = nil;
}


//---------------------------------------------------------------
#pragma mark - CoreMotion
//---------------------------------------------------------------

- (BOOL)isPermissionsGrantedForCoreMotion {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#else
    return [CMSensorRecorder isAuthorizedForRecording];
#endif
}

- (void)requestForPermissionCoreMotionWithCompletion:(SBAPermissionsBlock)completion {

    __weak typeof(self) weakSelf = self;
    
    // Usually this method is called on another thread, but since we are searching
    // within same date to same date, it will return immediately, so put it on the main thread
    [self.motionActivityManager queryActivityStartingFromDate:[NSDate date] toDate:[NSDate date] toQueue:[NSOperationQueue mainQueue] withHandler:^(NSArray * __unused activities, NSError *error) {
        if (!error) {
            weakSelf.coreMotionPermissionStatus = SBAPermissionStatusAuthorized;
            if (completion) {
                completion(YES, nil);
            }
        } else if (error != nil && error.code == CMErrorMotionActivityNotAuthorized) {
            weakSelf.coreMotionPermissionStatus = SBAPermissionStatusDenied;

            if (completion) {
                completion(NO, [SBAPermissionsManager permissionDeniedErrorForType:SBAPermissionsTypeCoremotion]);
            }
        }
    }];
}


//---------------------------------------------------------------
#pragma mark - Microphone
//---------------------------------------------------------------

- (BOOL)isPermissionsGrantedForMicrophone {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#else
    return ([[AVAudioSession sharedInstance] recordPermission] == AVAudioSessionRecordPermissionGranted);
#endif
}

- (void)requestForPermissionMicrophoneWithCompletion:(SBAPermissionsBlock)completion {
    
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            if (completion) {
                completion(YES, nil);
            }
        } else {
            if (completion) {
                completion(NO, [SBAPermissionsManager permissionDeniedErrorForType:SBAPermissionsTypeMicrophone]);
            }
        }
    }];
}

//---------------------------------------------------------------
#pragma mark - Camera
//---------------------------------------------------------------
    
- (BOOL)isPermissionsGrantedForCamera {
#if TARGET_IPHONE_SIMULATOR
        return YES;
#else
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    return status == AVAuthorizationStatusAuthorized;
#endif
}

- (void)requestForPermissionCameraWithCompletion:(SBAPermissionsBlock)completion {
    
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if(granted){
            if (completion) {
                completion(YES, nil);
            }
        } else {
            if (completion) {
                completion(NO, [SBAPermissionsManager permissionDeniedErrorForType:SBAPermissionsTypeCamera]);
            }
        }
    }];
}

//---------------------------------------------------------------
#pragma mark - PhotoLibrary
//---------------------------------------------------------------

- (BOOL)isPermissionsGrantedForPhotoLibrary {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    return (status == PHAuthorizationStatusAuthorized);
}

- (void)requestForPermissionPhotoLibraryWithCompletion:(SBAPermissionsBlock)completion {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        BOOL isAuthorized = (status == PHAuthorizationStatusAuthorized);
        NSError *error = isAuthorized ? nil : [SBAPermissionsManager permissionDeniedErrorForType:SBAPermissionsTypePhotoLibrary];
        if (completion) {
            completion(isAuthorized, error);
        }
    }];
}

@end
