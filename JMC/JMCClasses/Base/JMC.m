/**
 Copyright 2011 Atlassian Software
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 **/
#import "JMC.h"
#import "JMCPing.h"
#import "JMCNotifier.h"
#import "JMCCrashSender.h"
#import "JMCCreateIssueDelegate.h"
#import "JMCRequestQueue.h"
#import "JMCIssuesViewController.h"
#include <sys/xattr.h>
#import "NSBundle+JMC.h"
#import "UIImage+JMC.h"
#import "CrashReporter.h"

@implementation JMCOptions
@synthesize url=_url, projectKey=_projectKey, apiKey=_apiKey,
            photosEnabled=_photosEnabled, voiceEnabled=_voiceEnabled, locationEnabled=_locationEnabled,
            crashReportingEnabled=_crashReportingEnabled, consoleLogEnabled=_consoleLogEnabled,
            notificationsEnabled=_notificationsEnabled, notificationsViaCustomView=_notificationsViaCustomView,
            barStyle=_barStyle, barTintColor=_barTintColor,
            customFields=_customFields, modalPresentationStyle=_modalPresentationStyle;

-(id)init
{
    if ((self = [super init])) {
        _photosEnabled = YES;
        _voiceEnabled = YES;
        _locationEnabled = NO;
        _crashReportingEnabled = YES;
        _notificationsEnabled = YES;
        _notificationsViaCustomView = NO;
        _consoleLogEnabled = NO;
        _barStyle = UIBarStyleDefault;
        _modalPresentationStyle = ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) ? 
                                    UIModalPresentationFormSheet : UIModalPresentationFullScreen;
    }
    return self;
}

+(id)optionsWithContentsOfFile:(NSString *)filePath
{
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:filePath];
    JMCOptions* options = [[JMCOptions alloc] init];
    options.url = [dict objectForKey:kJMCOptionUrl];
    options.projectKey = [dict objectForKey:kJMCOptionProjectKey];
    options.apiKey = [dict objectForKey:kJMCOptionApiKey];
    options.photosEnabled = [[dict objectForKey:kJMCOptionPhotosEnabled] boolValue];
    options.voiceEnabled = [[dict objectForKey:kJMCOptionVoiceEnabled] boolValue];
    options.locationEnabled = [[dict objectForKey:kJMCOptionLocationEnabled] boolValue];
    options.crashReportingEnabled = [[dict objectForKey:kJMCOptionCrashReportingEnabled] boolValue];
    options.notificationsEnabled = [[dict objectForKey:kJMCOptionNotificationsEnabled] boolValue];
    options.consoleLogEnabled = [[dict objectForKey:kJMCOptionConsoleLogEnabled] boolValue];
    options.notificationsViaCustomView = [[dict objectForKey:kJMCOptionNotificationsViaCustomView] boolValue];
    options.customFields = [dict objectForKey:kJMCOptionCustomFields];
    options.barStyle = [[dict objectForKey:kJMCOptionUIBarStyle] intValue];
    options.modalPresentationStyle = [[dict objectForKey:kJMCOptionUIModalPresentationStyle] intValue];
    return options;
}

+(id)optionsWithUrl:(NSString *)jiraUrl
            projectKey:(NSString*)projectKey
             apiKey:(NSString*)apiKey
             photos:(BOOL)photos
              voice:(BOOL)voice
           location:(BOOL)location
     crashReporting:(BOOL)crashreporting
      notifications:(BOOL)notifications
       customFields:(NSDictionary*)customFields
{
    NSAssert(projectKey != nil && [projectKey length] > 2, @"Invalid JMC: Project Key");
    NSAssert(jiraUrl != nil && [jiraUrl length] > 10, @"Invliad JMC: Url");
    NSAssert(apiKey != nil && apiKey.length > 10 , @"Invalid JMC: ApiKey");
    
    JMCOptions* options = [[JMCOptions alloc] init];
    options.url = jiraUrl;
    options.projectKey = projectKey;
    options.apiKey = apiKey;
    options.photosEnabled = photos;
    options.voiceEnabled = voice;
    options.locationEnabled = location;
    options.crashReportingEnabled = crashreporting;
    options.notificationsEnabled = notifications;
    options.customFields = customFields;
    return options;
}

- (id)copyWithZone:(NSZone *)zone
{
    JMCOptions* copy = [[JMCOptions alloc] init];
    copy.url = self.url;
    copy.projectKey = self.projectKey;
    copy.apiKey = self.apiKey;
    copy.photosEnabled = self.photosEnabled;
    copy.voiceEnabled = self.voiceEnabled;
    copy.locationEnabled = self.locationEnabled;
    copy.crashReportingEnabled = self.crashReportingEnabled;
    copy.notificationsEnabled = self.notificationsEnabled;
    copy.consoleLogEnabled = self.consoleLogEnabled;
    copy.notificationsViaCustomView = self.notificationsViaCustomView;
    copy.customFields = self.customFields;
    copy.barStyle = self.barStyle;
    copy.modalPresentationStyle = self.modalPresentationStyle;
    copy.barTintColor = self.barTintColor;
    return copy;
}


-(void)setUrl:(NSString*)url
{
    unichar lastChar = [url characterAtIndex:[url length] - 1];
    // if the lastChar is not a /, then add a /
    NSString* charToAppend = lastChar != '/' ? @"/" : @"";
    url = [url stringByAppendingString:charToAppend];

    _url = url;
}

-(void) dealloc
{
    self.url = nil;
}

@end


@interface JMC ()

@property (nonatomic, strong) JMCPing * _pinger;
@property (nonatomic, strong) JMCNotifier * _notifier;
@property (nonatomic, strong) JMCCrashSender *_crashSender;
@property (nonatomic, strong) NSString* _dataDirPath;


-(CGRect)notifierStartFrame;
-(CGRect)notifierEndFrame;
- (NSString *)makeDataDirPath;
- (void)generateAndStoreUUID;
@end

static BOOL started;
static JMCViewController* _jcViewController;

@implementation JMC

@synthesize customDataSource=_customDataSource;
@synthesize options=_options;
@synthesize url=_url;
@synthesize _pinger;
@synthesize _notifier;
@synthesize _crashSender;
@synthesize _dataDirPath;

+ (JMC *)sharedInstance {
    static JMC *singleton = nil;
    
    if (singleton == nil) {
        singleton = [[JMC alloc] init];
        started = NO;
    }
    return singleton;
}

- (void)dealloc
{
    self.customDataSource = nil;
}

-(id)init
{
    if ((self = [super init])) {
        JMCOptions* options = [[JMCOptions alloc] init];
        self.options = options;
        
        self._dataDirPath = [self makeDataDirPath];
        
        [self generateAndStoreUUID];

    }
    return self;
}


// TODO: call this when network becomes active after app becomes active
-(void)flushRequestQueue
{
    [[JMCRequestQueue sharedInstance] flushQueue];
}


- (void)generateAndStoreUUID
{
    // generate and store a UUID if none exists already
    if ([self getUUID] == nil) {
        
        NSString *uuid = nil;
        CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
        if (theUUID) {
           CFStringRef string = CFUUIDCreateString(NULL, theUUID);
           CFRelease(theUUID);
           uuid = (__bridge_transfer NSString *)string;
           if (uuid) {
              [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:kJIRAConnectUUID];
           }
        }
    }
}

- (void) configureJiraConnect:(NSString*) withUrl projectKey:(NSString*)project apiKey:(NSString *)apiKey
{
    JMCOptions *options = [self.options copy];
    options.url = withUrl;
    options.projectKey = project;
    options.apiKey = apiKey;
    [self configureWithOptions:options];
}

- (void) configureJiraConnect:(NSString*) withUrl
                   projectKey:(NSString*)project
                       apiKey:(NSString *)apiKey
                   dataSource:(id<JMCCustomDataSource>)customDataSource
{
    JMCOptions *options = [self.options copy];
    options.url = withUrl;
    options.projectKey = project;
    options.apiKey = apiKey;
    [self configureWithOptions:options dataSource:customDataSource];
}

- (void) configureJiraConnect:(NSString*) withUrl
                   projectKey:(NSString*) project
                       apiKey:(NSString *)apiKey
                     location:(BOOL) locationEnabled
                   dataSource:(id<JMCCustomDataSource>)customDataSource
{
    JMCOptions *options = [self.options copy];
    options.url = withUrl;
    options.projectKey = project;
    options.apiKey = apiKey;
    options.locationEnabled = locationEnabled;
    [self configureWithOptions:options dataSource:customDataSource];
}

- (void) configureWithOptions:(JMCOptions*)options {
    [self configureWithOptions:options dataSource:nil];
}

- (void) configureWithOptions:(JMCOptions*)options dataSource:(id<JMCCustomDataSource>)customDataSource {
    
    self.options = options;
  
    [self configureJiraConnect:options.url customDataSource:customDataSource];
}

- (void) configureJiraConnect:(NSString *)withUrl customDataSource:(id <JMCCustomDataSource>)customDataSource {
    self.options.url = withUrl;
    self.customDataSource = customDataSource;
    [self start];
}


-(BOOL) crashReportingIsEnabled {
    return self.options.crashReportingEnabled;
}

-(void) start {
    
    if ([self crashReportingIsEnabled]) {
        
        if (!self._crashSender) {
          self._crashSender = [[JMCCrashSender alloc] init];
        }
        
        [CrashReporter enableCrashReporter];

        dispatch_async(dispatch_get_main_queue(), ^{

            [NSTimer scheduledTimerWithTimeInterval:5
                                         target:_crashSender
                                       selector:@selector(promptThenMaybeSendCrashReports)
                                       userInfo:nil repeats:NO];
        });
        
    } else {
        JMCDLog(@"JMC Crash reporting disabled.");
    }


    if (self.options.notificationsEnabled) {

        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (_pinger) {
                [[NSNotificationCenter defaultCenter] removeObserver:_pinger]; // in case app was already configured, don't add a second observer.
            }
            
            self._pinger = [[JMCPing alloc] init];
                
            JMCNotifier* notifier = [[JMCNotifier alloc] initWithStartFrame:[self notifierStartFrame]
                                                                   endFrame:[self notifierEndFrame]];
                
            self._notifier = notifier;
            
            // whenever the Application Becomes Active, ping for notifications from JIRA.
            [[NSNotificationCenter defaultCenter] addObserver:_pinger
                                                     selector:@selector(start)
                                                         name:UIApplicationDidBecomeActiveNotification
                                                       object:nil];
            
        });
        
    } else {
        JMCDLog(@"Notifications are disabled.");
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        started = YES;
    });
    
    JMCDLog(@"JIRA Mobile Connect is configured with url: %@", self.url);
}

-(void) ping {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.options.notificationsEnabled) {
            [_pinger start];
        }
    });
}

-(NSURL*)url {
    return self.options.url ? [NSURL URLWithString:self.options.url] : nil;
}

-(JMCViewController*)createJMCViewController {
    return [[JMCViewController alloc] initWithNibName:@"JMCViewController" bundle:[NSBundle JMC_bundle]];
}

- (JMCViewController *)_jcController {
    if (_jcViewController == nil) {

        _jcViewController = [self createJMCViewController];
        _jcViewController.modalPresentationStyle = self.options.modalPresentationStyle;
    }
    return _jcViewController;
    
}

- (JMCIssuesViewController *)_issuesController {
    JMCIssuesViewController *viewController = [[JMCIssuesViewController alloc] initWithStyle:UITableViewStylePlain];
    [viewController loadView];
    [viewController setIssueStore:[JMCIssueStore instance]];
    viewController.modalPresentationStyle = self.options.modalPresentationStyle;
    return viewController;
}

- (UIViewController *)viewController
{
    return [self viewControllerWithMode:JMCViewControllerModeDefault];
}

- (UIViewController *)viewControllerWithMode:(enum JMCViewControllerMode)mode 
{
    if ([JMCIssueStore instance].count > 0) {
        return [self issuesViewControllerWithMode:mode];
    } else {
        return [self feedbackViewControllerWithMode:mode];
    }
}

- (UIViewController *)feedbackViewController
{
    return [self feedbackViewControllerWithMode:JMCViewControllerModeDefault];
}

- (UIViewController *)feedbackViewControllerWithMode:(enum JMCViewControllerMode)mode {
    if (mode == JMCViewControllerModeCustom) {
        return [self createJMCViewController]; // customview modes get a clean JMCViewController
    }
    else { // standard re-uses the same
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:[self _jcController]];
        navigationController.navigationBar.barStyle =  self.options.barStyle;
        navigationController.navigationBar.tintColor = self.options.barTintColor;
        navigationController.modalPresentationStyle = self.options.modalPresentationStyle;
        return navigationController;
    }
}

- (UIViewController *)issuesViewController
{
    return [self issuesViewControllerWithMode:JMCViewControllerModeDefault];
}

- (UIViewController *)issuesViewControllerWithMode:(enum JMCViewControllerMode)mode {
    if (mode == JMCViewControllerModeCustom) {
        return [self _issuesController]; 
    }
    else {
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:[self _issuesController]];
        navigationController.navigationBar.barStyle =  self.options.barStyle;
        navigationController.navigationBar.tintColor = self.options.barTintColor;
        navigationController.modalPresentationStyle = self.options.modalPresentationStyle;
        return navigationController;
    }
}

-(UIImage*) feedbackIcon {
    return [UIImage JMC_imageNamed:@"megaphone.png"];
}

- (NSDictionary *)getMetaData
{
    UIDevice *device = [UIDevice currentDevice];
    NSDictionary *appMetaData = [[NSBundle mainBundle] infoDictionary];
    NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:10];
    
    // add device data
    [info setObject:[self getUUID] forKey:@"uuid"];
    [info setObject:[device name] forKey:@"devName"];
    [info setObject:[device systemName] forKey:@"systemName"];
    [info setObject:[device systemVersion] forKey:@"systemVersion"];
    [info setObject:[device model] forKey:@"model"];

    NSLocale *locale = [NSLocale currentLocale];
    NSString *language = [locale displayNameForKey:NSLocaleLanguageCode
                                             value:[locale localeIdentifier]]; 

    if (language) [info setObject:language forKey:@"language"];
    
    // app application data
    NSString* bundleVersion = [appMetaData objectForKey:@"CFBundleVersion"];
    NSString* bundleVersionShort = [appMetaData objectForKey:@"CFBundleShortVersionString"];
    NSString* bundleName = [appMetaData objectForKey:@"CFBundleName"];
    NSString* bundleDisplayName = [appMetaData objectForKey:@"CFBundleDisplayName"];
    NSString* bundleId = [appMetaData objectForKey:@"CFBundleIdentifier"];
    if (bundleVersion) [info setObject:bundleVersion forKey:@"appVersion"];
    if (bundleVersionShort) [info setObject:bundleVersionShort forKey:@"appVersionShort"];
    if (bundleName) [info setObject:bundleName forKey:@"appName"];
    if (bundleDisplayName) [info setObject:bundleDisplayName forKey:@"appDisplayName"];
    if (bundleId) [info setObject:bundleId forKey:@"appId"];
    
    return info;
}

- (NSString *)getAppName
{
    NSDictionary *metaData = [self getMetaData];
    if ([metaData objectForKey:@"appName"])        return [metaData objectForKey:@"appName"];
    if ([metaData objectForKey:@"appDisplayName"]) return [metaData objectForKey:@"appDisplayName"];
    return @"this App";
}

- (NSString *)getUUID
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kJIRAConnectUUID];
}

- (NSString *) getAPIVersion
{
    return @"1.0"; // TODO: pull this from a map. make it a config, etc..
}

- (NSString *)getProject
{
    if ([_customDataSource respondsToSelector:@selector(project)]) {
        return [_customDataSource project]; // for backward compatibility with the beta... deprecated
    }
    if (self.options.projectKey != nil) {
        return self.options.projectKey;
    }
    return [self getAppName];
}


-(NSMutableDictionary *)getCustomFields
{
    NSMutableDictionary *customFields = [[NSMutableDictionary alloc] init];
    if ([_customDataSource respondsToSelector:@selector(customFields)]) {
        [customFields addEntriesFromDictionary:[_customDataSource customFields]];
    }
    if (_options.customFields) {
        [customFields addEntriesFromDictionary:_options.customFields];
    }
    return customFields;
}

-(NSArray *)components
{
    if ([_customDataSource respondsToSelector:@selector(components)]) {
        return [_customDataSource components];
    }
    return [NSArray arrayWithObject:@"iOS"];
}

-(NSString *)getApiKey
{
    return _options.apiKey ? _options.apiKey : @"";
}

- (BOOL)isPhotosEnabled {
    return _options.photosEnabled;
}

- (BOOL)isLocationEnabled {
    return _options.locationEnabled;
}

- (BOOL)isVoiceEnabled {
    return _options.voiceEnabled && [JMCRecorder audioRecordingIsAvailable]; // only enabled if device supports audio input
}

- (NSString*)issueTypeNameFor:(JMCIssueType)type useDefault:(NSString *)defaultType {
    
    switch (type) {
        case JMCIssueTypeFeedback:
            return @"Task";
            break;
        default:
            return @"Bug";
            break;
    }
    
//   No Need for Protocol Override:
//    if (([_customDataSource respondsToSelector:@selector(jiraIssueTypeNameFor:)])) {
//        NSString * typeName = [_customDataSource jiraIssueTypeNameFor:type];
//        if (typeName != nil) {
//            return typeName;
//        }
//    }
//    return defaultType;
}

-(UIBarStyle) getBarStyle {
    return _options.barStyle;
}


-(CGRect)notifierStartFrame
{
    if ([_customDataSource respondsToSelector:@selector(notifierStartFrame)]) {
        return [_customDataSource notifierStartFrame];
    }
    CGSize screenSize = [[UIScreen mainScreen] applicationFrame].size;
    return CGRectMake(0, screenSize.height + 40, screenSize.width, 40);
}

-(CGRect)notifierEndFrame
{
    if ([_customDataSource respondsToSelector:@selector(notifierEndFrame)]) {
        return [_customDataSource notifierEndFrame];
    }
    CGSize screenSize = [[UIScreen mainScreen] applicationFrame].size;
    return CGRectMake(0, screenSize.height - 20, screenSize.width, 40);
}

- (NSString *)dataDirPath 
{
    return self._dataDirPath;
}

// copied from http://developer.apple.com/library/ios/#qa/qa1719/_index.html
- (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL
{
    const char* filePath = [[URL path] fileSystemRepresentation];
    
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    
    int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
    return result == 0;
}

- (NSString *)makeDataDirPath 
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *cache = [paths objectAtIndex:0];
    NSString *dataDirPath = [cache stringByAppendingPathComponent:@"JMC"];
    
    if (![fileManager fileExistsAtPath:dataDirPath]) {
        [fileManager createDirectoryAtPath:dataDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [self addSkipBackupAttributeToItemAtURL:[NSURL URLWithString:dataDirPath]];
    return dataDirPath;
}




@end





@implementation JMC (PGDCore)


+ (void)setupJMCWithCustomAppFields:(NSDictionary * _Nullable)customFields completionBlock:(JMCSetupBlock _Nullable)completionBlock {
    
    __block JMC *aJmc = [JMC sharedInstance];
    __block BOOL success = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSMutableDictionary *configKeyPairs = [[JMC defaultKeyValuePairs] mutableCopy];
        
        //Append Optional Keys:  (Defaults are principal!)
        for (NSString *key in customFields) {
            if (![configKeyPairs objectForKey:key]) {
                id object = [customFields objectForKey:key];
                if (object != nil) {
                    [configKeyPairs setObject:object forKey:key];
                }
            }
        }
        
        // Set up JMC for JIRA tickets and crash reporting
        JMCOptions* options = [JMCOptions optionsWithUrl:_JMC_URL
                                              projectKey:_JMC_PROJECT_KEY
                                                  apiKey:_JMC_API_KEY
                                                  photos:YES
                                                   voice:YES
                                                location:YES
                                          crashReporting:YES
                                           notifications:YES
                                            customFields:configKeyPairs];
        
        [aJmc configureWithOptions:options];
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kAutomaticallySendCrashReports];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [aJmc ping];
        
        if(completionBlock)
            completionBlock(aJmc, success);
        
    });

}

+ (NSArray *)defaultCustomFieldKeys {
    
    return [[JMC defaultKeyValuePairs] allKeys];
    
}

+ (NSDictionary *)defaultKeyValuePairs {
    
    return @{
             @"AppId"       : APP_ID,
             @"AppVersion"  : [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],
             @"BundleId"    : [[NSBundle mainBundle] bundleIdentifier],
             @"Environment" : _ENVIRONMENT,
             @"Device_SLID" : @"MXN0KZE",
             @"UUID" : [self uniqueDeviceUDID],
             @"VendorId" : [[[UIDevice currentDevice] identifierForVendor] UUIDString]
             };
}

- (void)updateCustomField:(NSString * _Nonnull)key withObject:(id _Nonnull)object {

    NSMutableDictionary *mDict = [[JMC sharedInstance].options.customFields mutableCopy];
    
    NSArray *defaultKeys = [JMC defaultCustomFieldKeys];
    
    if(![defaultKeys containsObject:key]) {
        
        [mDict setObject:object forKey:key];
    }
    
}

- (NSString * _Nonnull)customFieldsAsPayloadString {
    
    NSMutableString *msg = [[NSMutableString alloc] initWithString:@"-["];
    
    NSDictionary *customFields = [JMC sharedInstance].options.customFields;
    
    for (NSString *key in [customFields mutableCopy]) {
        id obj = [customFields objectForKey:key];
        [msg appendFormat:@"%@: %@ \n", key, obj];
    }
    
    //Custom Application Configurations: <*Optional Key Stored in NSUserDefaults>
    id customAppConfigs = [[NSUserDefaults standardUserDefaults] objectForKey:@"application_configurations"];
    if(customAppConfigs != nil && [customAppConfigs isKindOfClass:[NSDictionary class]] && [[customAppConfigs allKeys] count] > 0) {
        [msg appendFormat:@"%@: %@ \n", @"application_configurations", customAppConfigs];
    }
    
    //Current User <*Optional>
    id currentUser = [[NSUserDefaults standardUserDefaults] objectForKey:@"Current_User_SLID"];
    if (currentUser != nil && [currentUser length] > 0) {
        [msg appendFormat:@"%@: %@ \n", @"Current_User_SLID", currentUser];
    }
    
    [msg appendString:@"]-"];
    
    return msg;
    
}

+ (NSUInteger)maxIssueSubjectTransmissionLength {
    return 80;
}

+ (NSUInteger)maxCrashDescriptionLength {
    return 600;
}

+ (NSString *)uniqueDeviceUDID
{
    NSString *rawUDID = @"";
    
#if TARGET_OS_IPHONE
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
        return [[UIDevice currentDevice] name];
    
    else
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
        {
            rawUDID = [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
#pragma clang diagnostic pop
            //rawUDID = @"30e19db0840b5678bb70d04783b8fbeb0004aj793nldy9";
            NSString *udidPrefix = [rawUDID substringToIndex:5];
            NSString *first = [udidPrefix substringToIndex:1];
            NSUInteger numberOfPrefixOccurrences = [[udidPrefix componentsSeparatedByString:first] count] - 1;
            if (numberOfPrefixOccurrences > 3)
            {
            }
            
            else
            {
#if TARGET_IPHONE_SIMULATOR
                return rawUDID;
#endif
                NSString *udidSufix = [rawUDID substringFromIndex:[rawUDID length]-5];
                NSString *last = [udidSufix substringToIndex:1];
                NSUInteger numberOfSufixOccurrences = [[udidSufix componentsSeparatedByString:last] count] - 1;
                if (numberOfSufixOccurrences > 3)
                {
                }
                
                else
                    return rawUDID;
            }
        }
        return [[UIDevice currentDevice] name];
    }
#endif
    return [[UIDevice currentDevice] name];
}

@end



