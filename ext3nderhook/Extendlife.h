#import <dlfcn.h>
#import <objc/runtime.h>
#import <notify.h>
#import <CommonCrypto/CommonCrypto.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <prefs.h>
#import <substrate.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "zlib.h"

#define NSLog(...)

#define DYLD_INTERPOSE(_replacement,_replacee) \
__attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
__attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

#import "NSData+GZIP.h"

extern const char *__progname;


#define isDeviceIPad (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

#define isInBackgound ([[UIApplication sharedApplication] applicationState]==UIApplicationStateBackground || [[UIApplication sharedApplication] applicationState]==UIApplicationStateInactive)



OBJC_EXTERN CFStringRef MGCopyAnswer(CFStringRef key) WEAK_IMPORT_ATTRIBUTE;


extern const char * origTeamID;
extern const char * myTeamID;


extern NSString* emailSt;
extern NSString* passSt;
extern NSString* deviceName;
extern NSString* deviceUdid;
extern NSString* teamID;
extern NSString* kChangelog;

extern "C" NSString* kVersion();
extern "C" void queueAlertBar(NSString* alertMessage);
extern "C" NSDictionary* accountLibraryDic();
extern "C" void showBanner(NSString* message, BOOL isError);
extern "C" void setNowWorkingEmail(NSString* rawEmailSt);
extern "C" NSData* AES128Ex(NSData* dataRaw, BOOL encrypt, NSString* key, NSString* iv);
extern "C" void installFileIpaAtPath(NSString* path);
extern "C" void signFileIpaAtPath(NSString* path);
extern "C" NSString* currentLocaleId();
extern "C" NSArray* getAllMails();
extern "C" NSString* getTeamForEmail(NSString* rawEmailSt);
extern "C" void goNextPackageQueued();

typedef enum {
    ConnectionTypeUnknown,
    ConnectionTypeNone,
    ConnectionType3G,
    ConnectionTypeWiFi
} ConnectionType;

extern "C" BOOL isNetworkReachable();

extern BOOL isInProgress;

@interface MCProfile : NSObject
+(id)profileDictionaryFromProfileData:(id)arg1 outError:(id*)arg2 ;
@end

@interface Ext3nderQueuedAlerts : NSObject
@property (strong) NSMutableArray *alerts;
@property (assign) BOOL isInLoogMessages;
@end

@interface Ext3nderQueuedAlertsNavs : NSObject
@property (strong) NSMutableDictionary *allNavs;
+ (instancetype) shared;
- (void)setNavBar:(id)arg1;
- (void)removeNavBar:(id)arg1;
- (void)queueMessageForAllNavs:(NSString*)arg1;
- (Ext3nderQueuedAlerts*)getQueueInfoForNav:(id)arg1;
@end

@interface NSObject ()
- (void)setOrigin:(CGPoint)arg1;
@end

@interface UINavigationBar ()
@property (nonatomic, strong) NSString *prompt;
@end

@interface Ext3nderCheck : NSObject
@property (nonatomic, strong) NSTimer *timerCheck;
+ (id) shared;
- (void)run_this;
- (void)timerCheckRestart;
- (void)criticalChanged;
@end

@interface CydiaObject
- (id)isReachable:(NSString*)host;
@end

@interface AADeviceInfo : NSObject
- (id) deviceName;
@end

@interface NSLocale ()
@property (nonatomic, readonly) NSString *identifier;
@end

@interface UITextField (Apple)
- (UITextField *) textInputTraits;
@end

@interface UIAlertView (Apple)
- (void) addTextFieldWithValue:(NSString *)value label:(NSString *)label;
- (id) buttons;
- (NSString *) context;
- (void) setContext:(NSString *)context;
- (void) setNumberOfRows:(int)rows;
- (void) setRunsModal:(BOOL)modal;
- (UITextField *) textField;
- (UITextField *) textFieldAtIndex:(NSUInteger)index;
- (void) _updateFrameForDisplay;
@end

@interface NSUserDefaults ()
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

typedef void (^CompletionBlock)();
typedef void (^CompletionBlockAction)(UIAlertAction *alertAction);
@interface UIAlertAction ()
@property (nonatomic, copy) CompletionBlockAction handler;
@end

@interface SettingsExtendlife : PSListController
+ (id) shared;
- (void)revokeCert;
- (void)requestTeamID:(BOOL)revoke;
- (void)saveAccount;
- (void)revokeAllKnowsAccounts;
@end

@interface ListAppIDsController : UITableViewController <UITableViewDelegate, UIActionSheetDelegate>
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSDictionary *data;
- (id)initWithEmail:(NSString*)email;
- (void)removeAppID:(NSString*)appId;
@end


@interface UIActionSheet ()
@property (strong) NSString *context;
@end

@interface DocumentsExtendlife : UITableViewController <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate, UIActionSheetDelegate, UIDocumentPickerDelegate>
{
	NSMutableArray *searchData;
	@private
	NSString *_path;
	NSArray *_files;
}
@property (strong) NSString *path;
@property (strong) NSArray *files;

+ (id) shared;
- (void)Refresh;
@end

@interface UIAlertController ()
- (void)_dismissWithAction:(id)arg1;
- (id)cancelAction;
- (void)_invokeHandlersForAction:(id)arg1;
@end

@interface Extender : NSObject
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(UIApplication *)sourceApplication annotation:(id)annotation;
- (BOOL)openURL:(NSURL*)url;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) long bundleModTime;
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSDictionary *entitlements;
@property (nonatomic, readonly) NSString *signerIdentity;
@property (nonatomic, readonly) BOOL profileValidated;
@property (nonatomic, readonly) NSString *shortVersionString;
@property (nonatomic, readonly) NSNumber *staticDiskUsage;
@property (nonatomic, readonly) NSString *teamID;
@property (nonatomic, readonly) NSString *applicationType;
@property (nonatomic, readonly) NSURL *bundleURL;
+ (id)applicationProxyForIdentifier:(id)arg1;
- (id)localizedName;
@end

@interface MCURLListenerListController : UITableViewController
@end
@interface MCProfileListController : MCURLListenerListController
@property (nonatomic, assign) BOOL isVisibleProfileController;
@end

@interface UITabBarItem ()
- (void)_setInternalTitle:(id)arg1;
@end

@class UIProgressIndicator;
@interface UIProgressHUD : UIView
- (void)done;
- (void)hide;
- (id)initWithWindow:(id)arg1;
- (void)setFontSize:(int)arg1;
- (void)setShowsText:(BOOL)arg1;
- (void)setText:(id)arg1;
- (void)show:(BOOL)arg1;
- (void)showInView:(id)arg1;
@end

@interface NSObject ()
+ (id)defaultWorkspace;
- (id)proxyAtIndexPath:(id)arg1;
- (void)resignForAppProxy:(LSApplicationProxy*)appProxy;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (id)allInstalledApplications;

-(BOOL)openApplicationWithBundleID:(id)arg1 ;

- (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options error:(NSError **)error;
- (BOOL)uninstallApplication:(NSString *)identifier withOptions:(NSDictionary *)options;
@end


@interface InstalledController : UITableViewController
- (void)_reloadData;
@end

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

@interface UIApplication (Private)
- (void)_setBackgroundStyle:(long long)style;
@end


#import <IOKit/IOKitLib.h>

extern "C" io_connect_t IORegisterForSystemPower(void * refcon, IONotificationPortRef * thePortRef, IOServiceInterestCallback callback, io_object_t * notifier );
extern "C" IOReturn IOAllowPowerChange( io_connect_t kernelPort, long notificationID );
extern "C" IOReturn IOCancelPowerChange(io_connect_t kernelPort, intptr_t notificationID);
extern "C" IOReturn IOPMSchedulePowerEvent(CFDateRef time_to_wake, CFStringRef my_id, CFStringRef type);
extern "C" IOReturn IODeregisterForSystemPower ( io_object_t * notifier );
extern "C" CFArrayRef IOPMCopyScheduledPowerEvents(void);

typedef uint32_t IOPMAssertionLevel;
typedef uint32_t IOPMAssertionID;
extern "C" IOReturn IOPMAssertionCreateWithName(CFStringRef AssertionType,IOPMAssertionLevel AssertionLevel, CFStringRef AssertionName, IOPMAssertionID *AssertionID);
extern "C" IOReturn IOPMAssertionRelease(IOPMAssertionID AssertionID);
#define iokit_common_msg(message)          (UInt32)(sys_iokit|sub_iokit_common|message)
#define kIOMessageCanSystemPowerOff iokit_common_msg( 0x240)
#define kIOMessageSystemWillPowerOff iokit_common_msg( 0x250) 
#define kIOMessageSystemWillNotPowerOff iokit_common_msg( 0x260)
#define kIOMessageCanSystemSleep iokit_common_msg( 0x270) 
#define kIOMessageSystemWillSleep iokit_common_msg( 0x280) 
#define kIOMessageSystemWillNotSleep iokit_common_msg( 0x290) 
#define kIOMessageSystemHasPoweredOn iokit_common_msg( 0x300) 
#define kIOMessageSystemWillRestart iokit_common_msg( 0x310) 
#define kIOMessageSystemWillPowerOn iokit_common_msg( 0x320)

#define kIOPMAutoPowerOn "poweron" 
#define kIOPMAutoShutdown "shutdown" 
#define kIOPMAutoSleep "sleep"
#define kIOPMAutoWake "wake"
#define kIOPMAutoWakeOrPowerOn "wakepoweron"


@interface UNMutableNotificationContent : NSObject
@property (nonatomic, copy) NSArray *attachments;
@property (nonatomic, copy) NSNumber *badge;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) NSString *categoryIdentifier;
@property (nonatomic, copy) NSString *darwinNotificationName;
@property (nonatomic, copy) NSString *darwinSnoozedNotificationName;
@property (getter=isFromSnooze, nonatomic) bool fromSnooze;
@property (nonatomic) bool hasDefaultAction;
@property (nonatomic, copy) NSString *launchImageName;
@property (nonatomic, copy) NSArray *peopleIdentifiers;
@property (nonatomic) bool shouldAddToNotificationsList;
@property (nonatomic) bool shouldAlwaysAlertWhileAppIsForeground;
@property (nonatomic) bool shouldLockDevice;
@property (nonatomic) bool shouldPauseMedia;
@property (getter=isSnoozeable, nonatomic) bool snoozeable;
@property (nonatomic, copy) id sound;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *threadIdentifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSDictionary *userInfo;
@end

@interface UNTimeIntervalNotificationTrigger : NSObject
+ (id)triggerWithTimeInterval:(double)arg1 repeats:(bool)arg2;
@end

@interface UNNotificationRequest : NSObject
+ (id)requestWithIdentifier:(id)arg1 content:(id)arg2 trigger:(id)arg3;
@end


@interface UNNotification : NSObject
@end

@interface UNUserNotificationCenter : NSObject
@property (nonatomic, assign) id delegate;
+ (id)currentNotificationCenter;
- (void)addNotificationRequest:(id)arg1 withCompletionHandler:(id /* block */)arg2;
- (void)requestAuthorizationWithOptions:(unsigned long long)arg1 completionHandler:(id /* block */)arg2;
@end







