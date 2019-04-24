#import "Ext3nder_SpringBoard.h"
#import <substrate.h>

#define NSLog(...)

static BOOL Enabled;
static int DaysLeftResign;
static int intervalCheck;
static __strong NSArray* accountLibraryTeams;
static NSTimeInterval launchedExt3nderTimeStamp;
static io_connect_t gRootPort = MACH_PORT_NULL;
static BOOL canSystemSleep;
static NSTimeInterval sheduleCreationExt3nderTimeStamp;
static NSTimeInterval timeIntervalRevokedDate;


static void updateTimer(int afterSeconds)
{
	@try {
		float updatedInterval;
		@autoreleasepool {
			NSTimeInterval timeStampNow = [[NSDate date] timeIntervalSince1970];
			updatedInterval = (float)((sheduleCreationExt3nderTimeStamp-timeStampNow)+afterSeconds);
			NSLog(@"*** updateTimer() timer adjusted to %f", updatedInterval);
		}
		[NSObject cancelPreviousPerformRequestsWithTarget:[Ext3nderManager sharedInstance] selector:@selector(requestCheck) object:nil];
		[[Ext3nderManager sharedInstance] performSelector:@selector(requestCheck) withObject:nil afterDelay:updatedInterval];
	}@catch (NSException * e) {
		updateTimer(afterSeconds);
	}
}
static void sheduleWakeAndCheckAfterSeconds(int afterSeconds)
{
	@try {
		@autoreleasepool {
			NSArray* eventsArray = [(NSArray*)IOPMCopyScheduledPowerEvents()?:@[] copy];
			for(NSDictionary* shEventNow in eventsArray) {
				if(CFStringRef scheduledbyID = (CFStringRef)shEventNow[@"scheduledby"]) {
					if([[NSString stringWithFormat:@"%@", scheduledbyID] isEqualToString:@"com.cydia.Ext3nder"]) {
						IOPMCancelScheduledPowerEvent((CFDateRef)shEventNow[@"time"], (CFStringRef)shEventNow[@"scheduledby"], (CFStringRef)shEventNow[@"eventtype"]);
					}
				}
			}
		}
		NSDate *wakeTime = [[NSDate date] dateByAddingTimeInterval:(afterSeconds - 10)];
		IOPMSchedulePowerEvent((CFDateRef)wakeTime, CFSTR("com.cydia.Ext3nder"), CFSTR(kIOPMAutoWake));
		sheduleCreationExt3nderTimeStamp = [[NSDate date] timeIntervalSince1970];
		updateTimer(afterSeconds);
	}@catch (NSException * e) {
		sheduleWakeAndCheckAfterSeconds(afterSeconds);
	}
}
static BOOL isPendingSchedule()
{
	BOOL ret = NO;
	@try {
		@autoreleasepool {
			NSArray* eventsArray = [(NSArray*)IOPMCopyScheduledPowerEvents()?:@[] copy];
			for(NSDictionary* shEventNow in eventsArray) {
				if(CFStringRef scheduledbyID = (CFStringRef)shEventNow[@"scheduledby"]) {
					if([[NSString stringWithFormat:@"%@", scheduledbyID] isEqualToString:@"com.cydia.Ext3nder"]) {
						ret = YES;
						break;
					}
				}
			}
		}
	}@catch (NSException * e) {
		return isPendingSchedule();
	}
	return ret;
}

static void HandlePowerManagerEvent(void *inContext, io_service_t inIOService, natural_t inMessageType, void *inMessageArgument)
{
    if(inMessageType == kIOMessageSystemWillSleep) {
		IOAllowPowerChange(gRootPort, (long)inMessageArgument);
		NSLog(@"*** kIOMessageSystemWillSleep");
	} else if(inMessageType == kIOMessageCanSystemSleep) {
		if(canSystemSleep) {
			IOAllowPowerChange(gRootPort, (long)inMessageArgument);
		} else {
			IOCancelPowerChange(gRootPort, (long)inMessageArgument);
		}
		NSLog(@"*** kIOMessageCanSystemSleep %@", @(canSystemSleep));
	} else if(inMessageType == kIOMessageSystemHasPoweredOn) {
		NSLog(@"*** kIOMessageSystemHasPoweredOn");
		updateTimer(intervalCheck);
		if(!isPendingSchedule()) {
			canSystemSleep = NO;
		}
	}
}
static void preventSystemSleep()
{
	IONotificationPortRef notify;
	io_object_t notifier;
	gRootPort = IORegisterForSystemPower(NULL, &notify, HandlePowerManagerEvent, &notifier);
    if(gRootPort == MACH_PORT_NULL) {
        NSLog (@"IORegisterForSystemPower failed.");
    } else {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notify), kCFRunLoopDefaultMode);
    }
}









static NSDictionary* provisionDicFromBundleID(NSString* bundId)
{
	@try {
		if(LSApplicationProxy* appProxy = [LSApplicationProxy applicationProxyForIdentifier:bundId]) {
			if(NSData *fileData = [NSData dataWithContentsOfFile:[[[appProxy bundleURL] path] stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
				if(NSDictionary *plist = [MCProfile profileDictionaryFromProfileData:fileData outError:nil]) {
					return plist;
				}
			}
		}
	}@catch (NSException * e) {
		return @{};
	}
	return @{};
}

static int daysFromDate(NSDate* pDate)
{
	int days;
	@try {
		@autoreleasepool {
			days = ceil((([pDate timeIntervalSince1970]-[[NSDate date] timeIntervalSince1970])/86400));
		}
	}@catch (NSException * e) {
	}
    return days<0?0:days;
}

static BOOL needRevokeAndResignAll()
{
	@try {
	int countInstalledByAccount = 0;
	LSApplicationWorkspace* wokr = [LSApplicationWorkspace defaultWorkspace];
	for(LSApplicationProxy* appProxy in [wokr allInstalledApplications]) {
		if([appProxy profileValidated]&&appProxy.teamID&&[accountLibraryTeams containsObject:appProxy.teamID]) {
			if(NSDictionary* dicProvision = provisionDicFromBundleID(appProxy.applicationIdentifier)) {
				if(NSDate* validateDate = dicProvision[@"ExpirationDate"]) {
					countInstalledByAccount++;
					int daysLeft = daysFromDate(validateDate);
					if(timeIntervalRevokedDate != 0) {
						if(NSDate* creationDate = dicProvision[@"CreationDate"]) {
							if(timeIntervalRevokedDate > [creationDate timeIntervalSince1970]) {
								daysLeft = 0;
							}
						}
					}
					NSLog(@"Date: %@ -- daysLeft %d", validateDate, daysLeft);
					if(!(daysLeft > DaysLeftResign)) {
						return YES;
					}
				} else {
					return YES;
				}
			}
		}
	}
	NSString* autoSignPth = [@"/var/mobile/Documents/Ext3nder" stringByAppendingPathComponent:@"AutoSign"];
	NSArray* filesAutoSign = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:autoSignPth error:nil]?:@[];
	int countSignFiles = [filesAutoSign count];
	if(countInstalledByAccount==0&&(countSignFiles>0)) {
		return YES;
	}
	for(NSString* fileNameNow in filesAutoSign) {
		NSString* storedBundleID = [[NSUserDefaults standardUserDefaults] objectForKey:fileNameNow inDomain:@"com.julioverne.ext3nder.autosign"];
		if(storedBundleID!=nil) {
			if(NSDictionary* dicProvision = provisionDicFromBundleID(storedBundleID)) {
				if(NSDate* validateDate = dicProvision[@"ExpirationDate"]) {
					int daysLeft = daysFromDate(validateDate);
					if(timeIntervalRevokedDate != 0) {
						if(NSDate* creationDate = dicProvision[@"CreationDate"]) {
							if(timeIntervalRevokedDate > [creationDate timeIntervalSince1970]) {
								daysLeft = 0;
							}
						}
					}
					NSLog(@"AutoSingFiles --> Date: %@ -- daysLeft %d", validateDate, daysLeft);
					if(!(daysLeft > DaysLeftResign)) {
						return YES;
					}
				} else {
					return YES;
				}
			}
		}
	}
	
	if(NSString* passwordS = [[NSUserDefaults standardUserDefaults] objectForKey:@"SavePass" inDomain:@"com.cydia.Ext3nder"]) {
		if(passwordS.length > 1) {
			if(NSString* mailS = [[NSUserDefaults standardUserDefaults] objectForKey:@"SaveMail" inDomain:@"com.cydia.Ext3nder"]) {
				if(mailS.length > 1) {
					return YES;
				}
			}
		}
	}
	
	}@catch (NSException * e) {
		return needRevokeAndResignAll();
	}
	return NO;
}

static BOOL getExternalStatus()
{
	@autoreleasepool {
		uint64_t status = 0;
		int notify_token;
		if (notify_register_check("com.julioverne.ext3nder.status", &notify_token) == NOTIFY_STATUS_OK) {
			notify_get_state(notify_token, &status);
			notify_cancel(notify_token);
		}
		if(status!=0) {
			return YES;
		}
		return NO;
	}
}

static _finline void UpdateExternalStatus(uint64_t newStatus)
{
    int notify_token;
    if (notify_register_check("com.julioverne.ext3nder.status", &notify_token) == NOTIFY_STATUS_OK) {
        notify_set_state(notify_token, newStatus);
        notify_cancel(notify_token);
    }
    notify_post("com.julioverne.ext3nder.status");
}


@implementation Ext3nderManager
+ (id)sharedInstance
{
	static Ext3nderManager *Ext3nderManagerC = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Ext3nderManagerC = [[Ext3nderManager alloc] init];
    });
    return Ext3nderManagerC;
}
- (void)requestCheck
{
	canSystemSleep = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_requestCheck) object:nil];
	[self performSelector:@selector(_requestCheck) withObject:nil afterDelay:2];
}
- (void)_requestCheck
{
	NSLog(@"*** _requestCheck Notify Check...");
	notify_post("com.julioverne.ext3nder/Check");
}
- (void)RegisterActions
{
    if (access("/usr/lib/libactivator.dylib", F_OK) == 0) {
		dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
	    if (Class la = objc_getClass("LAActivator")) {
			[[la sharedInstance] registerListener:(id<LAListener>)self forName:@"com.julioverne.ext3nder"];
		}
	}
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	return @"Ext3nder";
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	return @"Action For Revoke And Resign All.";
}
- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
    static __strong UIImage* listenerIcon;
    if (!listenerIcon) {
		listenerIcon = [[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Applications/Ext3nder.app"] pathForResource:scale==2.0f?@"AppIcon29x29@2x":@"AppIcon29x29" ofType:@"png"]];
	}
    return listenerIcon;
}
- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
    static __strong UIImage* listenerIcon;
    if (!listenerIcon) {
		listenerIcon = [[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Applications/Ext3nder.app"] pathForResource:scale==2.0f?@"AppIcon29x29@2x":@"AppIcon29x29" ofType:@"png"]];
	}
    return listenerIcon;
}
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	@autoreleasepool {
		UpdateExternalStatus(1);
	}
}
- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return getExternalStatus()?FSSwitchStateOn:FSSwitchStateOff;
}
- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[self activator:nil receiveEvent:nil];
}
- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[[%c(FSSwitchPanel) sharedPanel] openURLAsAlternateAction:[NSURL URLWithString:@"cyext://"]];
}
@end



static void settingsChangedExt3nder(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		Enabled = (BOOL)([[[NSUserDefaults standardUserDefaults] objectForKey:@"AutoSignEnabled" inDomain:@"com.cydia.Ext3nder"]?:@NO boolValue]);
		
		NSDictionary* accountLibraryDic = [[NSUserDefaults standardUserDefaults] objectForKey:@"accountLibrary" inDomain:@"com.cydia.Ext3nder"]?:[NSDictionary dictionary];
		NSMutableArray* accountLibraryTeamsMut = [NSMutableArray array];
		NSArray* arrMail = [accountLibraryDic allKeys];
		for(NSString* emailStNow in arrMail) {
			[accountLibraryTeamsMut addObject:accountLibraryDic[emailStNow][@"team"]];
		}
		accountLibraryTeams = [accountLibraryTeamsMut copy];
		
		if(NSDate* revokedDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"revokedDate" inDomain:@"com.cydia.Ext3nder"]) {
			timeIntervalRevokedDate = [revokedDate timeIntervalSince1970];
		} else {
			timeIntervalRevokedDate = 0;
		}
		DaysLeftResign = (int)[[[NSUserDefaults standardUserDefaults] objectForKey:@"DaysLeftResign" inDomain:@"com.cydia.Ext3nder"]?:@(2) intValue];
		int newIntervalCheck = (int)[[[NSUserDefaults standardUserDefaults] objectForKey:@"intervalCheck" inDomain:@"com.cydia.Ext3nder"]?:@(7200) intValue];
		if(intervalCheck!=0 && intervalCheck!=newIntervalCheck) {
			intervalCheck = newIntervalCheck;
			sheduleWakeAndCheckAfterSeconds(intervalCheck);
		}
		intervalCheck = newIntervalCheck;
	}
}

static void notifyExt3nderNeedKilled(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@try{
		@autoreleasepool {
			SBApplicationController* controller = [%c(SBApplicationController) sharedInstance];
			SBApplication* sbapp = [controller applicationWithBundleIdentifier:@"com.cydia.Ext3nder"];
			BOOL isAppRunning = [sbapp respondsToSelector:@selector(isRunning)]?[sbapp isRunning]:[[controller runningApplications] containsObject:sbapp];
			if(sbapp&&isAppRunning) {
				FBApplicationProcess* SBProc = MSHookIvar<FBApplicationProcess *>(sbapp, "_process");
				[SBProc killForReason:1 andReport:NO withDescription:nil completion:nil];
				//BKSTerminateApplicationForReasonAndReportWithDescription(@"com.cydia.Ext3nder", 5, false, NULL);
				NSLog(@"*** Ext3nder Killed...");
				return;
			}
			NSLog(@"*** Ext3nder No Process to be Killed...");
		}
	}@catch (NSException * e) {
	}
}
static void notifyExt3nderLaunched(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		canSystemSleep = YES;
		launchedExt3nderTimeStamp = [[NSDate date] timeIntervalSince1970];
		NSLog(@"*** Ext3nder Launched Suspended...");
	}
}

extern "C" int SBSLaunchApplicationWithIdentifier(CFStringRef identifier, Boolean suspended);

static void launchExt3nderAndDisableSleep()
{
	@try{
		@autoreleasepool {
			NSLog(@"*** Ext3nder AutoSign Execution...");
			SBApplicationController* controller = [%c(SBApplicationController) sharedInstance];
			SBApplication* sbapp = [controller applicationWithBundleIdentifier:@"com.cydia.Ext3nder"];
			BOOL isAppRunning = [sbapp respondsToSelector:@selector(isRunning)]?[sbapp isRunning]:[[controller runningApplications] containsObject:sbapp];
			if(sbapp&&isAppRunning) {
				NSLog(@"*** PASS> Ext3nder is Running...");
				canSystemSleep = YES;
			} else {
				dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					SBSLaunchApplicationWithIdentifier(CFSTR("com.cydia.Ext3nder"), YES);
					NSLog(@"*** Ext3nder Launch Request...");
				});
			}
		}
	}@catch (NSException * e) {
	}
}

static void ext3nderCheckAutoSignerRun(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@try{
		@autoreleasepool {
			sheduleWakeAndCheckAfterSeconds(intervalCheck);
			if(!Enabled || !needRevokeAndResignAll()) {
				canSystemSleep = YES;
			} else {
				launchExt3nderAndDisableSleep();
			}
		}
	}@catch (NSException * e) {
	}
}

static void stateChangedExt3nder(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		if(getExternalStatus()) {
			launchExt3nderAndDisableSleep();
		}
		if(%c(FSSwitchPanel) != nil) {
			[[%c(FSSwitchPanel) sharedPanel] stateDidChangeForSwitchIdentifier:@"com.julioverne.ext3nder"];
		}
	}
}

%group HooksSB
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
	%orig;
	sheduleWakeAndCheckAfterSeconds(5);
}
%end
%end


%ctor
{	
	@autoreleasepool {
		canSystemSleep = YES;
		preventSystemSleep();
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChangedExt3nder, CFSTR("com.julioverne.extendlife/Settings"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, notifyExt3nderNeedKilled, CFSTR("com.julioverne.ext3nder/Exit"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, ext3nderCheckAutoSignerRun, CFSTR("com.julioverne.ext3nder/Check"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, notifyExt3nderLaunched, CFSTR("com.julioverne.ext3nder/Launched"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, stateChangedExt3nder, CFSTR("com.julioverne.ext3nder.status"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		settingsChangedExt3nder(NULL, NULL, NULL, NULL, NULL);
		[[Ext3nderManager sharedInstance] RegisterActions];
		%init(HooksSB);
	}	
}
