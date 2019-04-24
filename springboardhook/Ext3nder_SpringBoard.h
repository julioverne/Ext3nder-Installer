#include <stdio.h>
#include <stdlib.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <sys/sysctl.h>
#import <notify.h>

extern const char *__progname;

extern "C" void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *bundleID, int reasonID, bool report, NSString *description);

@interface MCProfile : NSObject
+(id)profileDictionaryFromProfileData:(id)arg1 outError:(id*)arg2 ;
@end

@interface FBApplicationProcess : NSObject
- (void)killForReason:(long long)arg1 andReport:(BOOL)arg2 withDescription:(id)arg3 completion:(/*^block*/id)arg4 ;
@end

@interface SBApplication : NSObject
@property (readonly, nonatomic) int pid;
- (BOOL)isRunning; // <= iOS 10 
- (NSString *)bundleIdentifier;
- (void)clearDeactivationSettings;
- (id)mainScreenContextHostManager;
- (id)mainSceneID;
- (void)activate;
- (void)setFlag:(long long)arg1 forActivationSetting:(unsigned int)arg2;
- (void)processDidLaunch:(id)arg1;
- (void)processWillLaunch:(id)arg1;
- (void)resumeForContentAvailable;
- (void)resumeToQuit;
- (void)_sendDidLaunchNotification:(BOOL)arg1;
- (void)notifyResumeActiveForReason:(long long)arg1;
- (void)setApplicationState:(unsigned int)applicationState;
@end

@interface SBApplicationController : NSObject
- (SBApplication*)applicationWithBundleIdentifier:(NSString *)identifier;
- (NSArray*)runningApplications; // >= iOS 9
+ (instancetype)sharedInstance;
@end

@interface UIApplication (Private)
-(BOOL)launchApplicationWithIdentifier:(NSString*)bundleID suspended:(BOOL)suspended;
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
@property (nonatomic, readonly) NSURL *bundleURL;
+ (id)applicationProxyForIdentifier:(id)arg1;
- (id)localizedName;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (id)allInstalledApplications;
- (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options error:(NSError **)error;
- (BOOL)uninstallApplication:(NSString *)identifier withOptions:(NSDictionary *)options;
@end

#import <IOKit/IOKitLib.h>

extern "C" io_connect_t IORegisterForSystemPower(void * refcon, IONotificationPortRef * thePortRef, IOServiceInterestCallback callback, io_object_t * notifier );
extern "C" IOReturn IOAllowPowerChange( io_connect_t kernelPort, long notificationID );
extern "C" IOReturn IOCancelPowerChange(io_connect_t kernelPort, intptr_t notificationID);
extern "C" IOReturn IOPMSchedulePowerEvent(CFDateRef time_to_wake, CFStringRef my_id, CFStringRef type);
extern "C" IOReturn IOPMCancelScheduledPowerEvent(CFDateRef time_to_wake, CFStringRef my_id, CFStringRef type);
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

@interface UNUserNotificationCenter : NSObject
@property (nonatomic, assign) id delegate;
- (void)addObserver:(id)arg1;
@end

// Firmware >= 9.0 & 10.0
@interface UNSNotificationScheduler : NSObject
@property (nonatomic, assign) id delegate;
@property (nonatomic, retain) UNUserNotificationCenter *userNotificationCenter;
- (id)initWithBundleIdentifier:(id)bundleIdentifier;
- (void)_addScheduledLocalNotifications:(NSArray *)notifications withCompletion:(id)completion;
- (void)cancelAllScheduledLocalNotifications;
@end

#import <libactivator/libactivator.h>
#import <Flipswitch/Flipswitch.h>

@interface Ext3nderManager : NSObject <FSSwitchDataSource>
+ (id)sharedInstance;
- (void)requestCheck;
- (void)RegisterActions;
@end

@interface NSUserDefaults ()
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
@end
