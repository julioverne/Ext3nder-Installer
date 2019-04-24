#import "Extendlife.h"





const char * origTeamID;
const char * myTeamID;
static BOOL disableVPN;
static BOOL disableTemp = YES;
static BOOL enabledHK = YES;
static BOOL showUserApp;
static BOOL saveSignedApp;
static BOOL allowCydiaSubstrate;
static BOOL showAuthenticationNotification;
BOOL showRevokeNotification;
BOOL BackgroundTranslucent;
BOOL fastZipCompression;
static BOOL AutoSignEnabled;
static int DaysLeftResign;
static BOOL isCritical;
static int secondsIntervalAutoResign;
static BOOL needToBeKilled;
static BOOL appStartedInBackgroundMode;
static int errorCount;
__strong NSString* preferredEmail;
__strong NSString* emailSt;
__strong NSString* passSt;
__strong NSString* deviceName;
__strong NSString* deviceUdid;
__strong NSString* teamID;

static NSURL* lastIpaUrlFilePath;
static __strong NSString* currentBundleID;
static BOOL isInLoopPackage;
static BOOL allowMeToInstallIpaInLoop;

static BOOL notificationAlerts;
static BOOL notificationErrors;


__strong NSMutableArray* recentInstalledBundleIDAfterRevoke = [[NSMutableArray alloc] init];
__strong NSMutableArray* installedBundleIdForResign = [[NSMutableArray alloc] init];
__strong NSMutableArray* ipaFilePathForResign = [[NSMutableArray alloc] init];



BOOL isInProgress;

static NSMutableArray* queuedAlertsBar = [[NSMutableArray alloc] init];

extern "C" void queueAlertBar(NSString* alertMessage)
{
	if(isInBackgound) {
		return;
	}
	[[Ext3nderQueuedAlertsNavs shared] queueMessageForAllNavs:alertMessage];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/statusInfoChanged" object:nil];
}

extern "C" NSString* currentLocaleId()
{
	static NSString* retLeng;
	if(!retLeng) {
		retLeng = [[NSLocale currentLocale] identifier]?:@"en_US";
	}
	return retLeng;
}

extern "C" NSData* AES128Ex(NSData* dataRaw, BOOL encrypt, NSString* key, NSString* iv)
{
	CCOperation operation = encrypt?kCCEncrypt:kCCDecrypt;
    char keyPtr[kCCKeySizeAES128 + 1];
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    char ivPtr[kCCBlockSizeAES128 + 1];
    bzero(ivPtr, sizeof(ivPtr));
    if (iv) {
		[iv getCString:ivPtr maxLength:sizeof(ivPtr) encoding:NSUTF8StringEncoding];
    }
    NSUInteger dataLength = [dataRaw length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(operation,
					  kCCAlgorithmAES128,
					  kCCOptionPKCS7Padding | kCCOptionECBMode,
					  keyPtr,
					  kCCBlockSizeAES128,
					  ivPtr,
					  [dataRaw bytes],
					  dataLength,
					  buffer,
					  bufferSize,
					  &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
	return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    free(buffer);
    return nil;
}

extern "C" NSDictionary* accountLibraryDic()
{
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"accountLibrary"]?:[NSDictionary dictionary];
}

static NSArray* getAllTeams()
{
	NSMutableArray* ret = [NSMutableArray array];
	NSArray* arrMail = [accountLibraryDic() allKeys];
	for(NSString* emailStNow in arrMail) {
		[ret addObject:accountLibraryDic()[emailStNow][@"team"]];
	}
	return ret;
}
extern "C" NSArray* getAllMails()
{
	return [accountLibraryDic() allKeys];
}
static NSString* getPassForEmail(NSString* rawEmailSt)
{
	if(NSDictionary* accountInfo = accountLibraryDic()[rawEmailSt]) {
		if(NSData* encriptedPass = accountInfo[@"pass"]) {
			NSData* dataPass = AES128Ex(encriptedPass, NO, @"\x01\x00\x07\x08\x00\x04\x03", nil);
			return [[NSString alloc] initWithData:dataPass encoding:NSUTF8StringEncoding];
		}
	}
	return nil;
}
extern "C" NSString* getTeamForEmail(NSString* rawEmailSt)
{
	if(NSDictionary* accountInfo = accountLibraryDic()[rawEmailSt]) {
		return accountInfo[@"team"];
	}
	return nil;
}
static NSString* getEmailForTeam(NSString* rawTeamSt)
{
	NSArray* arrMail = [accountLibraryDic() allKeys];
	if(rawTeamSt) {
		for(NSString* emailStNow in arrMail) {
			NSDictionary* accountInfoNow = accountLibraryDic()[emailStNow];
			NSString* temaNow = accountInfoNow[@"team"];
			if(temaNow&&[temaNow isEqualToString:rawTeamSt]) {
				return emailStNow;
			}
		}
	}
	if(preferredEmail&&[arrMail containsObject:preferredEmail]) {
		return preferredEmail;
	}
	if([arrMail count] > 0) {
		return arrMail[0];
	}
	return nil;
}
extern "C" void setNowWorkingEmail(NSString* rawEmailSt)
{
	if(!rawEmailSt||(passSt&&myTeamID&&rawEmailSt&&emailSt&&[rawEmailSt isEqualToString:emailSt])) {
		return;
	}
	emailSt = [rawEmailSt copy];
	passSt = getPassForEmail(emailSt);
	myTeamID = getTeamForEmail(emailSt).UTF8String;
}


static ConnectionType connectionType()
{
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, "8.8.8.8");
    SCNetworkReachabilityFlags flags;
    BOOL success = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    if (!success) {
		return ConnectionTypeUnknown;
    }
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL isNetworkReachable = (isReachable && !needsConnection);
    if (!isNetworkReachable) {
		return ConnectionTypeNone;
    } else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
		return ConnectionType3G;
    } else {
		return ConnectionTypeWiFi;
    }
}

extern "C" BOOL isNetworkReachable()
{
	
	ConnectionType status = connectionType();
	return !(status==ConnectionTypeUnknown||status==ConnectionTypeNone);
}

static io_connect_t gRootPort = MACH_PORT_NULL;
static io_object_t notifier;
static IOPMAssertionID assertionID;

static void exitExt3nder()
{
	NSLog(@"*** Killing Ext3nder...");
	if(notifier) {
		IODeregisterForSystemPower(&notifier);
		notifier = 0;
	}
	if(assertionID) {
		IOPMAssertionRelease(assertionID);
		assertionID = 0;
	}
	notify_post("com.julioverne.ext3nder/Exit");
}

static void HandlePowerManagerEvent(void *inContext, io_service_t inIOService, natural_t inMessageType, void *inMessageArgument)
{
    if(inMessageType == kIOMessageSystemWillSleep) {
		IOAllowPowerChange(gRootPort, (long)inMessageArgument);
		NSLog(@"*** kIOMessageSystemWillSleep");
	} else if(inMessageType == kIOMessageCanSystemSleep) {
		IOCancelPowerChange(gRootPort, (long)inMessageArgument);
		NSLog(@"*** kIOMessageCanSystemSleep -- BLOCKED");
	}
}

static void preventSystemSleep()
{
	IONotificationPortRef notify;
	gRootPort = IORegisterForSystemPower(NULL, &notify, HandlePowerManagerEvent, &notifier);
    if(gRootPort == MACH_PORT_NULL) {
        NSLog (@"IORegisterForSystemPower failed.");
    } else {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notify), kCFRunLoopDefaultMode);
    }
    IOReturn err = IOPMAssertionCreateWithName(CFSTR("NoIdleSleepAssertion"), 255, CFSTR("Keep Alive For Ext3nder Resign"), &assertionID);
    if(err != kIOReturnSuccess) {
		NSLog(@"*** IOPMAssertionCreateWithName failed.");
    }
}

static __strong NSString* oldMessage;
extern "C" void showBanner(NSString* message, BOOL isError)
{
	NSLog(@"showBanner[%d]: %@", (int)isError, message);
	queueAlertBar(message);
	if(!notificationAlerts&&!isError) {
		return;
	}
	if(!notificationErrors&&isError) {
		return;
	}
	//if(isInBackgound) {
		if(!isError&&oldMessage&&[oldMessage isEqualToString:message]) {
			return;
		}
		
		if(kCFCoreFoundationVersionNumber>=1348.00) { // 1348.00 iOS10
			UNMutableNotificationContent *localNotification = [[%c(UNMutableNotificationContent) alloc] init];
			localNotification.title = isError?[[NSBundle mainBundle] localizedStringForKey:@"ERROR" value:@"ERROR" table:nil]:nil;
			localNotification.body = message;
			localNotification.sound = nil;
			localNotification.badge = @([[UIApplication sharedApplication] applicationIconBadgeNumber]);
			
			UNTimeIntervalNotificationTrigger *trigger = [%c(UNTimeIntervalNotificationTrigger) triggerWithTimeInterval:0.1f repeats:NO];
			UNNotificationRequest *request = [%c(UNNotificationRequest) requestWithIdentifier:[NSString stringWithFormat:@"ext3nder%f", [[NSDate date] timeIntervalSince1970]] content:localNotification trigger:trigger];
			UNUserNotificationCenter *center = [%c(UNUserNotificationCenter) currentNotificationCenter];
			[center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
				//
			}];
		} else {
			if(isInBackgound) {
				UILocalNotification *localNotification = [[UILocalNotification alloc] init];
				localNotification.fireDate = [NSDate date];
				localNotification.alertBody = [NSString stringWithFormat:@"%@",message];
				localNotification.soundName = UILocalNotificationDefaultSoundName;
				[[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
			} else {
				dispatch_async(dispatch_get_main_queue(), ^{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"%@",message] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
					[alert show];
				});
			}
		}
		oldMessage = [message copy];
	//}	
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

static NSString* timeIntervalStringFromDate(NSDate* bundleModifiedTimestamp, BOOL timeAgo)
{
	NSDate *now = [NSDate date];
	unsigned int unitFlags = NSCalendarUnitSecond | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitDay;
	static __strong NSCalendar* _calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	NSDateComponents *conversionInfo = [_calendar components:unitFlags fromDate:timeAgo?bundleModifiedTimestamp:now toDate:timeAgo?now:bundleModifiedTimestamp options:0];
	int seconds = (int)conversionInfo.second;
	int minutes = (int)conversionInfo.minute;
	int hours = (int)conversionInfo.hour;
	int days = (int)conversionInfo.day;
	NSString *daysStr = [NSString stringWithFormat:@"%d day", days];
	if(hours != 1) {
		daysStr = [daysStr stringByAppendingString:@"s"];
	}
	NSString *hoursStr = [NSString stringWithFormat:@"%d hour", hours];
	if(hours != 1) {
		hoursStr = [hoursStr stringByAppendingString:@"s"];
	}
	NSString *minStr = [NSString stringWithFormat:@"%d minute", minutes];
	if(minutes != 1) {
		minStr = [minStr stringByAppendingString:@"s"];
	}
	NSString *secStr = [NSString stringWithFormat:@"%d second", seconds];
	if(seconds != 1) {
		secStr = [secStr stringByAppendingString:@"s"];
	}
	NSString* str = @"";
	if(days > 0) {
		str = [str stringByAppendingFormat:@"%@, %@", daysStr, hoursStr];
	} else if (hours > 0) {
		str = [str stringByAppendingFormat:@"%@, %@", hoursStr, minStr];
	} else if (minutes > 0) {
		str = [str stringByAppendingFormat:@"%@, %@", minStr, secStr];
	} else {
		str = [str stringByAppendingFormat:@"%@", secStr];
	}
	return [str stringByAppendingString:timeAgo?@" ago":@" left"];
}


extern "C" void installFileIpaAtPath(NSString* path)
{
	if(!path) {
		return;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		isInProgress = YES;
		NSString* file = [path lastPathComponent];
		queueAlertBar([NSString stringWithFormat:@"Copying File \"%@\"", file]);
		
		[[NSFileManager defaultManager] copyItemAtPath:path toPath:[path stringByAppendingPathExtension:@"install"] error:nil];
		queueAlertBar([@"Installing " stringByAppendingString:file]);
		
		LSApplicationWorkspace *workspace = [objc_getClass("LSApplicationWorkspace") performSelector:@selector(defaultWorkspace)];
		NSError* error = nil;
		NSMutableDictionary* options = [[NSMutableDictionary alloc] init];
		if(NSString* storedBundleID = [[NSUserDefaults standardUserDefaults] objectForKey:file inDomain:@"com.julioverne.ext3nder.autosign"]) {
			options[@"CFBundleIdentifier"] = storedBundleID;
		}
		options[@"AllowInstallLocalProvisioned"] = @YES;
		if([workspace installApplication:[NSURL fileURLWithPath:[path stringByAppendingPathExtension:@"install"]] withOptions:options error:&error]) {
			NSString* installedSt = [[[NSBundle mainBundle] localizedStringForKey:@"INSTALLED" value:@"Installed" table:nil] stringByAppendingString:@": "];
			installedSt = [installedSt stringByAppendingString:file];
			showBanner(installedSt, NO);
		} else {
			NSString* failedSt = [[[NSBundle mainBundle] localizedStringForKey:@"ERROR" value:@"Error" table:nil] stringByAppendingString:@" ("];
			failedSt = [failedSt stringByAppendingString:file];
			failedSt = [failedSt stringByAppendingString:@") "];
			if(error) {
				failedSt = [failedSt stringByAppendingString:@": \n"];
				failedSt = [failedSt stringByAppendingString:[error localizedDescription]];
			}
			showBanner(failedSt, YES);
		}
		isInProgress = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/appChanged" object:nil];
		[[NSFileManager defaultManager] removeItemAtPath:[path stringByAppendingPathExtension:@"install"] error:nil];
	});
}


extern "C" void signFileIpaAtPath(NSString* path)
{
	if([getAllMails() count] > 0) {
		setNowWorkingEmail(getAllMails()[0]);
	}
	[(Extender*)[UIApplication sharedApplication] application:[UIApplication sharedApplication] openURL:[NSURL fileURLWithPath:path] sourceApplication:nil annotation:nil];
}

static NSURL* repackIpaWithAppProxy(LSApplicationProxy* appProxy, BOOL isIpaTemp)
{
	isInProgress = YES;
	queueAlertBar([@"Build " stringByAppendingString:[[[[[appProxy bundleURL] lastPathComponent] stringByDeletingPathExtension] stringByAppendingFormat:@"_%@", appProxy.shortVersionString] stringByAppendingPathExtension:@"ipa"]]);
	
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSString* sharedDocs = [[fileManager containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path];
	
	NSURL* urlpth = [appProxy bundleURL];
	NSString* appFolderName = [[urlpth lastPathComponent] stringByDeletingPathExtension];
	
	NSString* ipaFileName = [[appFolderName stringByAppendingFormat:@"_%@", appProxy.shortVersionString] stringByAppendingPathExtension:@"ipa"];
	
	
	NSString* ipaFolderRepack = [[sharedDocs stringByAppendingPathComponent:ipaFileName] stringByAppendingPathExtension:@"repacking"];
	[fileManager createDirectoryAtPath:ipaFolderRepack withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile", NSFilePosixPermissions:@0755,} error:nil];
	
	NSString* urlpthSt = [urlpth path];
	urlpthSt = [urlpthSt stringByDeletingLastPathComponent];
	NSLog(@"copy: %@ -- %@", urlpthSt, ipaFolderRepack);
	system([NSString stringWithFormat:@"cp -rf \"%@\" \"%@\"", urlpthSt, ipaFolderRepack].UTF8String);
	system([NSString stringWithFormat:@"mv -f \"%@\" \"%@\"", [ipaFolderRepack stringByAppendingPathComponent:[urlpthSt lastPathComponent]], [ipaFolderRepack stringByAppendingPathComponent:@"Payload"]].UTF8String);
	
	
	system([NSString stringWithFormat:@"cd \"%@\";mv -f ./{.,}* ../", [ipaFolderRepack stringByAppendingPathComponent:@"Payload"]].UTF8String);
	system([NSString stringWithFormat:@"cd \"%@\";mv -f *.app Payload", ipaFolderRepack].UTF8String);
	
	
	NSString* IPAPathSt = [[sharedDocs stringByAppendingPathComponent:appFolderName] stringByAppendingPathExtension:@"ipa"];	
	system([NSString stringWithFormat:@"cd \"%@\";zip -ry%@ \"../%@\" .", ipaFolderRepack, fastZipCompression?@"0":@"9", [IPAPathSt lastPathComponent]].UTF8String);
	
	//[SSZipArchive createZipFileAtPath:IPAPathSt withContentsOfDirectory:ipaFolderRepack keepParentDirectory:NO withPassword:nil andProgressHandler:NULL];
	
	
	NSString* documentsSt = [[fileManager containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path];
	if(isIpaTemp) {
		documentsSt = [documentsSt stringByAppendingPathComponent:@"IPA_tmp"];
		[fileManager createDirectoryAtPath:documentsSt withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile", NSFilePosixPermissions:@0755,} error:nil];
	}
	NSString* destPth = [documentsSt stringByAppendingPathComponent:ipaFileName];
	NSDictionary *attributes = [fileManager attributesOfItemAtPath:IPAPathSt error:nil];
	if(attributes&&[attributes[NSFileSize] intValue]>50) {
		[fileManager removeItemAtPath:destPth error:nil];
		[fileManager moveItemAtPath:IPAPathSt toPath:destPth error:nil];
	}
	
	
	[fileManager removeItemAtPath:ipaFolderRepack error:nil];	
	queueAlertBar([@"Build Done " stringByAppendingString:[[[[[appProxy bundleURL] lastPathComponent] stringByDeletingPathExtension] stringByAppendingFormat:@"_%@", appProxy.shortVersionString] stringByAppendingPathExtension:@"ipa"]]);
	isInProgress = NO;
	return [NSURL fileURLWithPath:destPth];
}

static void resignForAppProxy(LSApplicationProxy* appProxy, BOOL fromLoopList, NSString* withMail)
{
	if(!appProxy) {
		return;
	}
	NSLog(@"*** resignForAppProxy: %@", appProxy.applicationIdentifier);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		NSURL* ipaURL = repackIpaWithAppProxy(appProxy, YES);
		NSString* IPASt = [ipaURL path];
		if([[NSFileManager defaultManager] fileExistsAtPath:IPASt isDirectory:nil]) {
			NSString* withMailSt = withMail!=nil?withMail:getEmailForTeam(appProxy.teamID);
			if(withMailSt) {
				NSString* withMailTeam = getTeamForEmail(withMailSt);
				if(appProxy.teamID&&withMailTeam&&![appProxy.teamID isEqualToString:withMailTeam]) {
					isInProgress = YES;
					NSString* appName = [[appProxy localizedName] copy];
					queueAlertBar([@"Uninstalling " stringByAppendingString:appName]);
					LSApplicationWorkspace *workspace = [LSApplicationWorkspace performSelector:@selector(defaultWorkspace)];
					[workspace uninstallApplication:appProxy.applicationIdentifier withOptions:nil];
					queueAlertBar([@"Uninstalled " stringByAppendingString:appName]);
					isInProgress = NO;
				}
			}
			setNowWorkingEmail(withMailSt);
			if(fromLoopList) {
				allowMeToInstallIpaInLoop = YES;
			}
			[(Extender*)[UIApplication sharedApplication] application:[UIApplication sharedApplication] openURL:[NSURL fileURLWithPath:IPASt] sourceApplication:[UIApplication sharedApplication] annotation:nil];
			if(fromLoopList) {
				allowMeToInstallIpaInLoop = NO;
			}
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/documentsChanged" object:nil];
	});
}
static void repackSaveForAppProxy(LSApplicationProxy* appProxy)
{
	if(!appProxy) {
		return;
	}
	NSLog(@"*** repackSaveForAppProxy: %@", appProxy.applicationIdentifier);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		NSURL* ipaURL = repackIpaWithAppProxy(appProxy, NO);
		if(ipaURL) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/documentsChanged" object:nil];
		}		
	});
}


extern "C" void goNextPackageQueued()
{
	if(![installedBundleIdForResign count] && ![ipaFilePathForResign count]) {
		if(isInLoopPackage) {
			isInLoopPackage = NO;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/inLoopPackageChanged" object:nil];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				queueAlertBar([[NSBundle mainBundle] localizedStringForKey:@"DONE" value:@"Done" table:nil]);
			});
			NSLog(@"*** goNextPackageQueued() FINISHED");
			if(needToBeKilled&&isInBackgound) {
				exitExt3nder();
			}
		}		
		return;
	}
	if(!isInLoopPackage) {
		isInLoopPackage = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/inLoopPackageChanged" object:nil];
	}
	if([ipaFilePathForResign count] > 0) {
		NSString *ipaPathSt = [[ipaFilePathForResign firstObject] copy];
		[ipaFilePathForResign removeObjectAtIndex:0];
		if([[NSFileManager defaultManager] fileExistsAtPath:ipaPathSt isDirectory:nil]) {
			NSString* teamIDApp = nil;
			if(NSString* storedBundleID = [[NSUserDefaults standardUserDefaults] objectForKey:[ipaPathSt lastPathComponent] inDomain:@"com.julioverne.ext3nder.autosign"]) {
				if(LSApplicationProxy* lsAppProxy = [LSApplicationProxy applicationProxyForIdentifier:storedBundleID]) {
					teamIDApp = lsAppProxy.teamID;
				}
			}
			setNowWorkingEmail(getEmailForTeam(teamIDApp));
			allowMeToInstallIpaInLoop = YES;
			[(Extender*)[UIApplication sharedApplication] application:[UIApplication sharedApplication] openURL:[NSURL fileURLWithPath:ipaPathSt] sourceApplication:[UIApplication sharedApplication] annotation:nil];
			allowMeToInstallIpaInLoop = NO;
		}		
	} else if([installedBundleIdForResign count] > 0) {
		NSString *bundleIdResign = [[installedBundleIdForResign firstObject] copy];
		[installedBundleIdForResign removeObjectAtIndex:0];
		if([recentInstalledBundleIDAfterRevoke indexOfObject:bundleIdResign] != NSNotFound) {
			NSLog(@"*** goNextPackageQueued() ignoring... installed by local file .ipa %@", bundleIdResign);
			[recentInstalledBundleIDAfterRevoke removeObject:bundleIdResign];
			goNextPackageQueued();
		} else {
			if(LSApplicationProxy* lsAppProxy = [LSApplicationProxy applicationProxyForIdentifier:bundleIdResign]) {
				currentBundleID = bundleIdResign;
				[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/appChanged" object:nil];
				resignForAppProxy(lsAppProxy, YES, nil);
			}
		}
	}
}

static void revokeResignAll()
{
	if(isInLoopPackage) {
		return;
	}
	
	installedBundleIdForResign = [[NSMutableArray alloc] init];
	ipaFilePathForResign = [[NSMutableArray alloc] init];
	
	LSApplicationWorkspace* wokr = [LSApplicationWorkspace defaultWorkspace];
	for(LSApplicationProxy* appProxy in [wokr allInstalledApplications]) {
		if([appProxy profileValidated]&&appProxy.teamID&&[getAllTeams() containsObject:appProxy.teamID]) {
			[installedBundleIdForResign addObject:appProxy.applicationIdentifier];
		}
	}
	
	NSString* autoSignPath = [[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path] stringByAppendingPathComponent:@"AutoSign"];
	NSArray* filesAutoSign = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:autoSignPath error:nil]?:@[];
	for(NSString* fileNow in filesAutoSign) {
		[ipaFilePathForResign addObject:[autoSignPath stringByAppendingPathComponent:fileNow]];
	}
	
	if([installedBundleIdForResign count]>0 || [ipaFilePathForResign count]>0) {
		[[SettingsExtendlife shared] revokeAllKnowsAccounts];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/appChanged" object:nil];
	NSLog(@"*** revokeResignAll()> installedBundleIdForResign %@ \n ipaFilePathForResign %@", installedBundleIdForResign, ipaFilePathForResign);
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



static BOOL needRevokeAndResignAll()
{
	@try {
	NSDate* revokedDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"revokedDate"];
	int countInstalledByAccount = 0;
	LSApplicationWorkspace* wokr = [LSApplicationWorkspace defaultWorkspace];
	for(LSApplicationProxy* appProxy in [wokr allInstalledApplications]) {
		if([appProxy profileValidated]&&appProxy.teamID&&[getAllTeams() containsObject:appProxy.teamID]) {
			if(NSDictionary* dicProvision = provisionDicFromBundleID(appProxy.applicationIdentifier)) {
				if(NSDate* validateDate = dicProvision[@"ExpirationDate"]) {
					countInstalledByAccount++;
					int daysLeft = daysFromDate(validateDate);
					if(revokedDate) {
						if(NSDate* creationDate = dicProvision[@"CreationDate"]) {
							if([revokedDate timeIntervalSince1970] > [creationDate timeIntervalSince1970]) {
								daysLeft = 0;
							}
						}
					}
					//NSLog(@"Date: %@ -- daysLeft %d", validateDate, daysLeft);
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
					if(revokedDate) {
						if(NSDate* creationDate = dicProvision[@"CreationDate"]) {
							if([revokedDate timeIntervalSince1970] > [creationDate timeIntervalSince1970]) {
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
	}@catch (NSException * e) {
		return needRevokeAndResignAll();
	}
	return NO;
}




%hook NSFileManager
- (id)containerURLForSecurityApplicationGroupIdentifier:(id)arg1
{
	return [NSURL fileURLWithPath:@"/var/mobile/Documents/Ext3nder"];
}
%end


%hook MCProfileListController
%property (nonatomic, assign) BOOL isVisibleProfileController;
- (void)viewDidLoad
{
	%orig;
	[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(_updateTitle) userInfo:nil repeats:YES];
}
- (void)viewWillAppear:(BOOL)arg1
{
	self.isVisibleProfileController = YES;
	%orig;
}
- (void)viewWillDisappear:(BOOL)arg1
{
	self.isVisibleProfileController = NO;
	%orig;
}
-(void)dealloc
{
    self.isVisibleProfileController = NO;
	%orig;
}
%new
- (void)_updateTitle
{
	if(!self.isVisibleProfileController) {
		return;
	}
	static NSString* kManageTitle = nil;
	if(!kManageTitle) {
		kManageTitle = [[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/ManagedConfigurationUI.bundle"] localizedStringForKey:@"DEVICE_MANAGEMENT" value:@"Device Management" table:@"ManagedConfigurationUI"];
	}
	self.title = nil;
	self.title = kManageTitle;
}
%end

 
%hook NEVPNManager
- (BOOL)hasLoaded
{
	if(disableVPN) {
		return YES;
	}
	return %orig;
}
- (void)setEnabled:(BOOL)arg1
{
	if(disableVPN) {
		enabledHK = arg1;
		return;
	}
	%orig(enabledHK);
}
- (void)saveToPreferencesWithCompletionHandler:(void (^)(NSError* error))completion
{
	if(disableVPN) {
		completion(nil);
		return;
	}
	%orig(completion);
}
%end

%hook NEVPNConnection
- (long long)status
{
	if(disableVPN) {
		return enabledHK?3:1;
	}
	return %orig;
}
- (BOOL)startVPNTunnelAndReturnError:(id*)arg1
{
	if(disableVPN) {
		return YES;
	}
	return %orig(arg1);
}
%end
%hook NETunnelProviderManager
+ (void)loadAllFromPreferencesWithCompletionHandler:(void (^)(NSArray * managers, NSError * error))completion
{
	if(disableVPN) {
		completion(@[], nil);
		return;
	}
	%orig(completion);
}
%end


static void revokeResignAllNow()
{
	if([getAllMails() count] == 0) {
		showBanner(@"Please, Setup Apple Account In Ex3nder", YES);
		return;
	}
	
	isCritical = YES;
	[[Ext3nderCheck shared] criticalChanged];
	if(!isNetworkReachable()) {
		showBanner([@"AutoSign: " stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"NETWORK_ERROR" value:@"Network Error" table:nil]], YES);
		return;
	}
	isCritical = NO;
	[[Ext3nderCheck shared] criticalChanged];
	
	needToBeKilled = YES;
	revokeResignAll();
}


static void stateChangedExt3nder(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		if(getExternalStatus()) {
			UpdateExternalStatus(0);
			revokeResignAllNow();
		}
	}
}

inline bool GetPrefBool(NSString *key)
{
	return [[[NSUserDefaults standardUserDefaults] objectForKey:key]?:@YES boolValue];
}

@implementation Ext3nderCheck
@synthesize timerCheck;
static __strong Ext3nderCheck *Ext3nderCheckC;
+ (id) shared
{	
	if (!Ext3nderCheckC) {
		Ext3nderCheckC = [[self alloc] init];
		[Ext3nderCheckC timerCheckRestart];
		NSLog(@"*** Ext3nderCheckC->shared");
	}
	return Ext3nderCheckC;
}
+ (BOOL)sharedExist
{
	if(Ext3nderCheckC) {
		return YES;
	}
	return NO;
}
- (void)timerCheckRestart
{
	if(timerCheck!=nil && [timerCheck isValid]) {
		[timerCheck invalidate]; 
	}
	if(!secondsIntervalAutoResign) {
		secondsIntervalAutoResign = 7200; /* 7200 = 2hour */
	}
	timerCheck = [NSTimer scheduledTimerWithTimeInterval:secondsIntervalAutoResign target:Ext3nderCheckC selector:@selector(RunUpdates) userInfo:nil repeats:YES];
}
- (void)criticalChanged
{
	if((isCritical&&secondsIntervalAutoResign==2400) || (!isCritical&&secondsIntervalAutoResign==7200)) {
		return;
	}
	secondsIntervalAutoResign = isCritical?2400:7200; /* 2400 = 40min /  7200 = 2hour */
	[self timerCheckRestart];
}
- (void)run_this
{
	NSLog(@"------ Ext3nderCheck RUN -----");
	return;
}
- (void)RunUpdates
{
	NSLog(@"*** RunUpdates()");
	if(!AutoSignEnabled) {
		return;
	}
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_RunUpdates) object:nil];
	[self performSelector:@selector(_RunUpdates) withObject:nil afterDelay:0.5f];
}
- (void)_RunUpdates
{
	NSLog(@"*** _RunUpdates()");
	if(!AutoSignEnabled) {
		return;
	}
	
	if([getAllMails() count] == 0) {
		showBanner(@"Please, Setup Apple Account In Ex3nder", YES);
		return;
	}
	
	if(needRevokeAndResignAll()) {
		
		revokeResignAllNow();
		
	} else if(appStartedInBackgroundMode && isInBackgound && !isCritical && !isInLoopPackage) {
		exitExt3nder();
	}
}
@end

%hook UNUserNotificationCenter
- (id)initWithBundleIdentifier:(NSString*)bundleID
{
    id result;
    if (!bundleID) {
        bundleID = @"com.cydia.Ext3nder";
    }
    @try {
        result = %orig(bundleID);
    } @catch (NSException *e) {
        result = %orig(@"com.cydia.Ext3nder");
    }
    return result;
}
%end

%hook Extender
%new
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(int options))completionHandler
{
    completionHandler((1 << 2));
}
%new
- (void)checkBackgroundAndKillIfInactive
{
	if(isInBackgound && !isCritical && !isInLoopPackage && !isInProgress) {
		exitExt3nder();
	}
}
%new
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler
{
	if(shortcutItem.type.integerValue == 1) {
		revokeResignAll();
    }
}
- (void)application:(id)application didFinishLaunchingWithOptions:(id)arg2
{
	if(isInBackgound) {
		appStartedInBackgroundMode = YES;
	}
	
	Class shortcutItemClass = objc_getClass("UIApplicationShortcutItem");
	if(shortcutItemClass!=NULL && [[UIApplication sharedApplication] respondsToSelector:@selector(setShortcutItems:)]) {
		NSMutableArray *shortcutItems = [NSMutableArray array];
		UIApplicationShortcutItem *resignAll = [[shortcutItemClass alloc]initWithType:@"1" localizedTitle:@"Resign All"];
		[shortcutItems addObject:resignAll];
		[[UIApplication sharedApplication] setShortcutItems:shortcutItems];
	}
	
	[NSTimer scheduledTimerWithTimeInterval:600.0f target:self selector:@selector(checkBackgroundAndKillIfInactive) userInfo:nil repeats:YES];
	
	NSString* sharedDocs = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path];
	
	[[NSFileManager defaultManager] createDirectoryAtPath:sharedDocs withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile", NSFilePosixPermissions:@0755,} error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[sharedDocs stringByAppendingPathComponent:@"AutoSign"] withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile", NSFilePosixPermissions:@0755,} error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[sharedDocs stringByAppendingPathComponent:@"Imported"] withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile", NSFilePosixPermissions:@0755,} error:nil];
	
	[[NSFileManager defaultManager] removeItemAtPath:[sharedDocs stringByAppendingPathComponent:@"Repacking"] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[sharedDocs stringByAppendingPathComponent:@"IPA_tmp"] error:nil];
	
	NSString* inboxPath = @"/var/mobile/Library/Application Support/Containers/com.cydia.Ext3nder/Documents/Inbox";
	NSString* importedPath = [sharedDocs stringByAppendingPathComponent:@"Imported"];
	for(NSString* fileNow in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:inboxPath error:nil]) {
		[[NSFileManager defaultManager] removeItemAtPath:[importedPath stringByAppendingPathComponent:fileNow] error:nil];
		[[NSFileManager defaultManager] moveItemAtPath:[inboxPath stringByAppendingPathComponent:fileNow] toPath:[importedPath stringByAppendingPathComponent:fileNow] error:nil];
	}
	
	%orig(application, arg2);
	
	
	@try {
		if(kCFCoreFoundationVersionNumber>=1348.00) {
			if ([(UIApplication*)self respondsToSelector:@selector(registerUserNotificationSettings:)]) {
				[(UIApplication*)self registerUserNotificationSettings:[objc_getClass("UIUserNotificationSettings") settingsForTypes:7 categories:nil]];
				[(UIApplication*)self registerForRemoteNotifications];
			} else {
				[(UIApplication*)self registerForRemoteNotificationTypes:7];
			}
			UNUserNotificationCenter *center = [%c(UNUserNotificationCenter) currentNotificationCenter];
			center.delegate = self;
			[center requestAuthorizationWithOptions:(1 << 2) completionHandler:^(BOOL granted, NSError * _Nullable error) {
				if (error) {
					//
				}
			}];
		} else {
			if([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
				[application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
				[application registerForRemoteNotifications];
			} else {
				[application registerForRemoteNotificationTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert)];
			}
		}
	} @catch (NSException * e) {
	}
	
	
	if(GetPrefBool([@"CDHackPopUp" stringByAppendingString:kVersion()]) && !isInBackgound) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[@"Extendlife v" stringByAppendingString:kVersion()] message:kChangelog delegate:nil cancelButtonTitle:@"Thanks, julioverne!" otherButtonTitles:nil];
		[alert show];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setBool:NO forKey:[@"CDHackPopUp" stringByAppendingString:kVersion()]];
		[defaults synchronize];
	}
	
	
	if(NSString* passwordS = [[NSUserDefaults standardUserDefaults] objectForKey:@"SavePass"]) {
		if(passwordS.length > 1) {
			if(NSString* mailS = [[NSUserDefaults standardUserDefaults] objectForKey:@"SaveMail"]) {
				if(mailS.length > 1) {
					SettingsExtendlife* settShared = [SettingsExtendlife shared];
					[settShared saveAccount];
				}
			}
		}
	}
	
	
	[[Ext3nderCheck shared] performSelector:@selector(RunUpdates) withObject:nil afterDelay:appStartedInBackgroundMode?(5):(40)];
	
	stateChangedExt3nder(NULL, NULL, NULL, NULL, NULL);
	
	if(BackgroundTranslucent&&[[UIApplication sharedApplication] respondsToSelector:@selector(_setBackgroundStyle:)]) {
		[[UIApplication sharedApplication] _setBackgroundStyle:3];
	}
	
	NSLog(@"*** application:didFinishLaunchingWithOptions:");
}
- (BOOL)openURL:(NSURL*)url
{
    if (url&&[[url absoluteString] hasPrefix:@"itms-services://?"]) {
		NSString* kName = nil;
		NSString* kBundle = nil;
		NSString* kVersion = nil;
		NSString* sharedDocs = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path];
		
		
		
		sharedDocs = [sharedDocs stringByAppendingPathComponent:@"Site"];
		sharedDocs = [sharedDocs stringByAppendingPathComponent:@"manifest.plist"];
		if(NSDictionary *manifest = [[NSDictionary alloc] initWithContentsOfFile:sharedDocs]) {
			if(NSArray* items = manifest[@"items"]) {
				for(NSDictionary* item in items) {
					if(NSDictionary* metadataDic = item[@"metadata"]) {
						kName = metadataDic[@"title"];
						kBundle = metadataDic[@"bundle-identifier"];
						currentBundleID = kBundle;
						[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/appChanged" object:nil];
						[[NSUserDefaults standardUserDefaults] setObject:kBundle forKey:[lastIpaUrlFilePath lastPathComponent] inDomain:@"com.julioverne.ext3nder.autosign"];
						if(isInLoopPackage) {
							if([recentInstalledBundleIDAfterRevoke indexOfObject:kBundle] == NSNotFound) {
								[recentInstalledBundleIDAfterRevoke addObject:kBundle];
							}
						}
						kVersion = metadataDic[@"bundle-version"];
					}
					break;
				}
			}
		}
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			isInProgress = YES;
			
			if(saveSignedApp) {
				queueAlertBar([@"Copying IPA Signed " stringByAppendingString:kName]);
				
				[[NSFileManager defaultManager] createDirectoryAtPath:[[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path] stringByAppendingPathComponent:@"Signed"] withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile", NSFilePosixPermissions:@0755,} error:nil];
				[[NSFileManager defaultManager] copyItemAtPath:[[[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path] stringByAppendingPathComponent:@"Site"] stringByAppendingPathComponent:@"signed.ipa"] toPath:[[[[[[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path] stringByAppendingPathComponent:@"Signed"] stringByAppendingPathComponent:kName?:@""] stringByAppendingString:@"_"] stringByAppendingString:[NSString stringWithFormat:@"%d",[@([[NSDate date] timeIntervalSince1970]) intValue]]] stringByAppendingPathExtension:@"ipa"] error:nil];
			}
			
			queueAlertBar([@"Installing " stringByAppendingString:kName]);
			
			LSApplicationWorkspace *workspace = [LSApplicationWorkspace performSelector:@selector(defaultWorkspace)];
			NSError* error = nil;
			NSMutableDictionary* options = [[NSMutableDictionary alloc] init];
			options[@"CFBundleIdentifier"] = kBundle;
			options[@"AllowInstallLocalProvisioned"] = @YES;
			BOOL isInstalled = NO;
			if([workspace installApplication:[NSURL fileURLWithPath:[[[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path] stringByAppendingPathComponent:@"Site"] stringByAppendingPathComponent:@"signed.ipa"]] withOptions:options error:&error]) {
				isInstalled = YES;
				//errorCount = 0;
			} else {
				isInstalled = NO;
				errorCount++;
			}
			
			currentBundleID = nil;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/appChanged" object:nil];
			
			isInProgress = NO;
			
			if(error && error.code == 13 && errorCount<2) {
				if(LSApplicationProxy* appProxy = [LSApplicationProxy applicationProxyForIdentifier:kBundle]) {
					queueAlertBar([[@"Uninstalling " stringByAppendingString:kName] stringByAppendingString:@" for handle error 13"]);
					[workspace uninstallApplication:appProxy.applicationIdentifier withOptions:nil];
					queueAlertBar([@"Uninstalled " stringByAppendingString:kName]);
				}
				
				allowMeToInstallIpaInLoop = YES;
				[(Extender*)[UIApplication sharedApplication] application:[UIApplication sharedApplication] openURL:lastIpaUrlFilePath sourceApplication:[UIApplication sharedApplication] annotation:nil];
				allowMeToInstallIpaInLoop = NO;
				return;
			}
			
			[[NSFileManager defaultManager] removeItemAtPath:[[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path] stringByAppendingPathComponent:@"Site"] error:nil];
			
			if(errorCount<2) {
				if(LSApplicationProxy* lsAppProxy = [LSApplicationProxy applicationProxyForIdentifier:kBundle]) {
					if(![lsAppProxy profileValidated] && lsAppProxy.teamID&&[getAllTeams() containsObject:lsAppProxy.teamID]) {
						errorCount++;
						if(isInLoopPackage) {
							allowMeToInstallIpaInLoop = YES;
						}
						[(Extender*)[UIApplication sharedApplication] application:[UIApplication sharedApplication] openURL:lastIpaUrlFilePath sourceApplication:[UIApplication sharedApplication] annotation:nil];
						if(isInLoopPackage) {
							allowMeToInstallIpaInLoop = NO;
						}
						return;
					}
				}
			}
			
			NSString* sharedDocs = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path];
			[[NSFileManager defaultManager] removeItemAtPath:[sharedDocs stringByAppendingPathComponent:@"IPA_tmp"] error:nil];
			
			
			
			if(error) {
				NSString* failedSt = [[[NSBundle mainBundle] localizedStringForKey:@"ERROR" value:@"Error" table:nil] stringByAppendingString:[NSString stringWithFormat:@" Code: %@", @(error.code)]];
				failedSt = [failedSt stringByAppendingString:@"\n "];
				failedSt = [failedSt stringByAppendingString:@" ("];
				failedSt = [failedSt stringByAppendingString:kName];
				failedSt = [failedSt stringByAppendingString:@") "];
				failedSt = [failedSt stringByAppendingString:@"\n "];
				failedSt = [failedSt stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"VERSION" value:@"Version" table:nil]];
				failedSt = [failedSt stringByAppendingString:@": "];
				failedSt = [failedSt stringByAppendingString:kVersion];
				if(error) {
					failedSt = [failedSt stringByAppendingString:@"\n "];
					failedSt = [failedSt stringByAppendingString:[error localizedDescription]];
				}
				queueAlertBar(failedSt);
				showBanner(failedSt, YES);
			} else if(errorCount >= 2) {
				NSString* failedSt = [[NSBundle mainBundle] localizedStringForKey:@"ERROR" value:@"Error" table:nil];
				failedSt = [failedSt stringByAppendingString:@"\n "];
				failedSt = [failedSt stringByAppendingString:@" ("];
				failedSt = [failedSt stringByAppendingString:kName];
				failedSt = [failedSt stringByAppendingString:@") "];
				failedSt = [failedSt stringByAppendingString:@"\n "];
				failedSt = [failedSt stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"VERSION" value:@"Version" table:nil]];
				failedSt = [failedSt stringByAppendingString:@": "];
				failedSt = [failedSt stringByAppendingString:kVersion];
				queueAlertBar(failedSt);
				showBanner(failedSt, YES);				
			} else if(isInstalled) {
				NSString* installedSt = [[[NSBundle mainBundle] localizedStringForKey:@"INSTALLED" value:@"Installed" table:nil] stringByAppendingString:@": "];
				installedSt = [installedSt stringByAppendingString:kName];
				installedSt = [installedSt stringByAppendingString:@"\n "];
				installedSt = [installedSt stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"VERSION" value:@"Version" table:nil]];
				installedSt = [installedSt stringByAppendingString:@": "];
				installedSt = [installedSt stringByAppendingString:kVersion];
				if(NSDictionary* dicProvision = provisionDicFromBundleID(kBundle)) {
					if(NSDate* validateDate = dicProvision[@"ExpirationDate"]) {
						installedSt = [installedSt stringByAppendingString:@"\n Valid: "];
						NSDateFormatter *dateFormat = [[NSDateFormatter alloc]init];
						[dateFormat setDateFormat:@"yyyy-MM-dd 'at' HH:mm"];
						installedSt = [installedSt stringByAppendingString:[dateFormat stringFromDate:validateDate]];
						installedSt = [installedSt stringByAppendingString:@" ("];
						installedSt = [installedSt stringByAppendingString:[@(daysFromDate(validateDate)) stringValue]];
						installedSt = [installedSt stringByAppendingString:@" Days Left"];
						installedSt = [installedSt stringByAppendingString:@")"];
					}
				}
				queueAlertBar(installedSt);
				showBanner(installedSt, NO);
			}

			if(!isInLoopPackage && needToBeKilled && isInBackgound) {
				exitExt3nder();
			}
			goNextPackageQueued();
		});
        return YES;
    } else {
        return %orig(url);
    }
}

- (NSArray*)defaultStartPages
{
	NSArray* ret = %orig;
	NSMutableArray* retMut = [ret mutableCopy];
	[retMut addObject:@[@"cyext://documents"]];
	[retMut addObject:@[@"cyext://profiles"]];
	[retMut addObject:@[@"cyext://settings"]];
	return [retMut copy];
}
- (id) pageForURL:(NSURL *)url forExternal:(BOOL)external withReferrer:(NSString *)referrer
{
	if(url) {
		NSString *scheme([[url scheme] lowercaseString]);
		if(scheme&&[scheme isEqualToString:@"cyext"]) {
			if([[url absoluteString] isEqualToString:@"cyext://documents"]) {
				return [DocumentsExtendlife shared];
			} else if([[url absoluteString] isEqualToString:@"cyext://profiles"]) {
				static __strong MCProfileListController* profileCont = [[%c(MCProfileListController) alloc] init];
				return profileCont;
			} else if([[url absoluteString] isEqualToString:@"cyext://settings"]) {
				return [SettingsExtendlife shared];
			} else if([[url absoluteString] hasPrefix:@"cyext://set_udid"]) {
				NSString *udidSt = [[url absoluteString] substringFromIndex:17];
				if(udidSt&&udidSt.length==40) {
					[[NSUserDefaults standardUserDefaults] setObject:udidSt forKey:@"deviceUdid"];
					[[NSUserDefaults standardUserDefaults] synchronize];
					notify_post("com.julioverne.extendlife/Settings");
				}				
				return nil;
			}
		}	
	}	
	return %orig(url, external, referrer);
}
- (BOOL)application:(id)arg1 openURL:(NSURL*)url sourceApplication:(id)arg3 annotation:(id)arg4
{
	NSLog(@"*** application:openURL:sourceApplication:annotation: %@", url);
	@try {
		if(url) {
			if(lastIpaUrlFilePath&&url && ![[lastIpaUrlFilePath absoluteString] isEqualToString:[url absoluteString]]) {
				errorCount = 0;
			}
			NSURL* fileIm = [url copy];
			if([fileIm isFileURL]) {
				
				currentBundleID = [[NSUserDefaults standardUserDefaults] objectForKey:[fileIm lastPathComponent] inDomain:@"com.julioverne.ext3nder.autosign"];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/appChanged" object:nil];
				
				NSString* sharedDocs = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path];
				sharedDocs = [sharedDocs stringByAppendingPathComponent:@"Imported"];
				
				[[NSFileManager defaultManager] createDirectoryAtPath:sharedDocs withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile", NSFilePosixPermissions:@0755,} error:nil];
				
				NSString* urlPth = [url path];
				if(urlPth&&([urlPth rangeOfString:@"/Ext3nder/"].location == NSNotFound)) {
					NSString* fileName = [urlPth lastPathComponent];
					queueAlertBar([NSString stringWithFormat:@"File \"%@\" Imported.", fileName]);
					NSURL* destURL = [NSURL fileURLWithPath:[sharedDocs stringByAppendingPathComponent:fileName]];
					[[NSFileManager defaultManager] moveItemAtURL:url toURL:destURL error:nil];
					url = destURL;
					[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/documentsChanged" object:nil];
				}
				
				if([getAllMails() count] == 0) {
					showBanner(@"Please, Setup Apple Account In Ex3nder", YES);
					return YES;
				}
			}
			if(isInLoopPackage&&!allowMeToInstallIpaInLoop) {
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ext3nder" message:@"Currently Installing Planeged List Of Packages. Please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
				[alert show];
				return YES;
			}
			lastIpaUrlFilePath = url;
		}
	} @catch (NSException * e) {
	}
	NSLog(@"*** application:openURL:sourceApplication:annotation: %@", url);
	__block BOOL ret;
	ret = NO;
	dispatch_async(dispatch_get_main_queue(), ^{
		ret = %orig(arg1, url, arg3, arg4);
	});
	return ret;
}
%end






@implementation Ext3nderQueuedAlerts
@synthesize alerts, isInLoogMessages;
- (id)init
{
	self = [super init];
	alerts = [[NSMutableArray alloc] init];
	return self;
}
@end
@implementation Ext3nderQueuedAlertsNavs
@synthesize allNavs;
static __strong Ext3nderQueuedAlertsNavs *Ext3nderQueuedAlertsNavsC;
+ (instancetype) shared
{	
	if (!Ext3nderQueuedAlertsNavsC) {
		Ext3nderQueuedAlertsNavsC = [[self alloc] init];
		Ext3nderQueuedAlertsNavsC.allNavs = [[NSMutableDictionary alloc] init];
		NSLog(@"*** Ext3nderQueuedAlertsNavsC->shared");
	}
	return Ext3nderQueuedAlertsNavsC;
}
- (void)setNavBar:(id)arg1
{
	allNavs[[NSString stringWithFormat:@"%p", arg1]] = [[Ext3nderQueuedAlerts alloc] init];	
}
- (void)removeNavBar:(id)arg1
{
	[allNavs removeObjectForKey:[NSString stringWithFormat:@"%p", arg1]];
}
- (void)queueMessageForAllNavs:(NSString*)arg1
{
	if(!arg1) {
		return;
	}
	for(NSString* navIdNow in [allNavs allKeys]) {
		Ext3nderQueuedAlerts* queueAlNav = (Ext3nderQueuedAlerts*)allNavs[navIdNow];
		[queueAlNav.alerts addObject:arg1];
	}
}
- (Ext3nderQueuedAlerts*)getQueueInfoForNav:(id)arg1
{
	return (Ext3nderQueuedAlerts*)allNavs[[NSString stringWithFormat:@"%p", arg1]];
}
@end
%hook UINavigationBar
- (id)initWithFrame:(CGRect)arg1
{
	id ret = %orig(arg1);
	
	[[Ext3nderQueuedAlertsNavs shared] setNavBar:self];
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] addObserver:ret selector:@selector(updateSubtitleStatus) name:@"com.julioverne.ext3nder/statusInfoChanged" object:nil];
	});
	return ret;
}
- (void)dalloc
{
	[[Ext3nderQueuedAlertsNavs shared] removeNavBar:self];
	dispatch_async(dispatch_get_main_queue(), ^{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateSubtitleStatus) object:nil];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetSubtitleStatus) object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	});	
	%orig;
}
%new
- (void)updateSubtitleStatus
{
	@try{
	if(isInBackgound) {
		return;
	}
	if(![[Ext3nderQueuedAlertsNavs shared] getQueueInfoForNav:self].isInLoogMessages) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self performSelector:@selector(_updateSubtitleStatus) withObject:nil afterDelay:0.1f];
		});
	}
	} @catch(NSException* ex) {
	}
}
%new
- (void)_updateSubtitleStatus
{
	@try{
		Ext3nderQueuedAlerts* QueueInfoForNav = [[Ext3nderQueuedAlertsNavs shared] getQueueInfoForNav:self];
		if([QueueInfoForNav.alerts count] == 0) {
			QueueInfoForNav.isInLoogMessages = NO;
			return;
		}
		NSString *cpMessageAl = [[QueueInfoForNav.alerts firstObject] copy];
		[QueueInfoForNav.alerts removeObjectAtIndex:0];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		@try{
		((UINavigationBar*)self).prompt = cpMessageAl;
		
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetSubtitleStatus) object:nil];
		[self performSelector:@selector(resetSubtitleStatus) withObject:nil afterDelay:4];
		
		if([QueueInfoForNav.alerts count] > 0) {
			QueueInfoForNav.isInLoogMessages = YES;
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateSubtitleStatus) object:nil];
			[self performSelector:@selector(_updateSubtitleStatus) withObject:nil afterDelay:0.3f];
		} else {
			QueueInfoForNav.isInLoogMessages = NO;
		}
		} @catch(NSException* ex) {
		}
	});
	} @catch(NSException* ex) {
	}
}
%new
- (void)resetSubtitleStatus
{
	dispatch_async(dispatch_get_main_queue(), ^{
		@try {
		if(isInLoopPackage || isInProgress) {
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetSubtitleStatus) object:nil];
			[self performSelector:@selector(resetSubtitleStatus) withObject:nil afterDelay:4];
		} else {
			Ext3nderQueuedAlerts* QueueInfoForNav = [[Ext3nderQueuedAlertsNavs shared] getQueueInfoForNav:self];
			QueueInfoForNav.isInLoogMessages = NO;
			if(((UINavigationBar*)self).prompt!=nil) {
				((UINavigationBar*)self).prompt = nil;
			}
		}
		} @catch(NSException* ex) {
		}
	});	
}
%end





static BOOL firstTimeOnlyShowReloadApps = YES;

%hook InstalledController
- (void)viewDidLoad
{
	%orig;
	
	[self performSelector:@selector(inLoopPackageChanged) withObject:nil];
	
	UIBarButtonItem *noButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
	((UIViewController*)self).navigationItem.rightBarButtonItems = @[noButtonItem];
	
	//UIBarButtonItem *noButtonItem1 = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
	//((UIViewController*)self).navigationItem.leftBarButtonItems = @[noButtonItem1];
	
	static __strong UIRefreshControl *refreshControl;
	if(!refreshControl) {
		refreshControl = [[UIRefreshControl alloc] init];
		[refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
		refreshControl.tag = 8654;
	}	
	if(UITableView* tableV = (UITableView *)object_getIvar(self, class_getInstanceVariable([self class], "list_"))) {
		if(UIView* rem = [tableV viewWithTag:8654]) {
			[rem removeFromSuperview];
		}
		[tableV addSubview:refreshControl];
		
		[tableV setRowHeight:130];
		
		if(BackgroundTranslucent) {
			tableV.alpha = 0.70;
			tableV.backgroundColor = [UIColor clearColor];
		}
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reloadData) name:@"com.julioverne.ext3nder/appChanged" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableData) name:@"com.julioverne.ext3nder/appChangedTable" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inLoopPackageChanged) name:@"com.julioverne.ext3nder/inLoopPackageChanged" object:nil];
}
%new
- (void)inLoopPackageChanged
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_inLoopPackageChanged) object:nil];
		[self performSelector:@selector(_inLoopPackageChanged) withObject:nil afterDelay:0.3f];
	});
}
%new
- (void)_inLoopPackageChanged
{
	@try {
	if(isInLoopPackage) {
		
		UIActivityIndicatorView* activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleGray];
		activityView.frame = CGRectMake(0, 0, 25, 25);
		[activityView sizeToFit];
		[activityView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)];
		UIBarButtonItem *loadingView = [[UIBarButtonItem alloc] initWithCustomView:activityView];
		((UIViewController*)self).navigationItem.leftBarButtonItems = @[loadingView];
		[activityView startAnimating];
		
		UIActivityIndicatorView* indicator_ = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:5];
		indicator_.tag = 4682;
		
		[indicator_ setOrigin:CGPointMake(kCFCoreFoundationVersionNumber >= 800 ? 2 : 4, 2)];
		[indicator_ startAnimating];
		UITabBarItem *item([[(UIViewController*)self navigationController] tabBarItem]);
		[item setBadgeValue:@""];
		UIView* badge = (UIView *)object_getIvar([(UIViewController*)item view], class_getInstanceVariable([[(UIViewController*)item view] class], "_badge"));
		[indicator_ startAnimating];
		[badge addSubview:indicator_];
		
	} else {
		
		UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:@"Resign All" style:UIBarButtonItemStylePlain target:self action:@selector(reinstallAllButtonClicked)];
		((UIViewController*)self).navigationItem.leftBarButtonItems = @[leftButton];
		
		UITabBarItem *item([[(UIViewController*)self navigationController] tabBarItem]);
		UIView* badge = (UIView *)object_getIvar([(UIViewController*)item view], class_getInstanceVariable([[(UIViewController*)item view] class], "_badge"));
		if(UIActivityIndicatorView* indicator_ = [badge viewWithTag:4682]) {
			[indicator_ removeFromSuperview];
			[indicator_ stopAnimating];
		}
		
		[item setBadgeValue:nil];
	}
	} @catch(NSException* ex) {
	}
}
%new
- (void)reloadTableData
{
	if(isInBackgound) {
		return;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reloadTableData) object:nil];
		[self performSelector:@selector(_reloadTableData) withObject:nil afterDelay:0.3f];
	});
}
%new
- (void)_reloadTableData
{
	if(UITableView* tableV = (UITableView *)object_getIvar(self, class_getInstanceVariable([self class], "list_"))) {
		[tableV reloadData];
	}
}
- (void)_reloadData
{
	if(isInBackgound) {
		return;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__reloadData) object:nil];
		[self performSelector:@selector(__reloadData) withObject:nil afterDelay:0];
	});
	//_orig(void);
}
%new
- (void)__reloadData
{
	static BOOL isInProgReload;
	if(isInProgReload) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__reloadData) object:nil];
		[self performSelector:@selector(__reloadData) withObject:nil afterDelay:0.5f];
		return;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		if(firstTimeOnlyShowReloadApps) {
			queueAlertBar(@"Loading Apps...");
		}
		isInProgReload = YES;
		@try {
			LSApplicationWorkspace* wokr = [LSApplicationWorkspace defaultWorkspace];
			NSMutableArray* appToShow = [[NSMutableArray alloc] init];
			for(LSApplicationProxy* appProxy in [wokr allInstalledApplications]) {
				if([appProxy profileValidated] || (showUserApp&&![[appProxy applicationType]?:@"" isEqualToString:@"System"])) {
					[appToShow addObject:appProxy];
				}
			}
			object_setInstanceVariable(self, "proxies_", *(NSMutableArray **)((uintptr_t)&appToShow));
			if(firstTimeOnlyShowReloadApps) {
				queueAlertBar([NSString stringWithFormat:@"%@ Apps Available", @([appToShow count])]);
			}
			firstTimeOnlyShowReloadApps = NO;
		} @catch(NSException* ex) {
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			if(UITableView* tableV = (UITableView *)object_getIvar(self, class_getInstanceVariable([self class], "list_"))) {
				[tableV performSelector:@selector(reloadData) withObject:nil afterDelay:0.5f];
			}
			
			isInProgReload = NO;
		});
	});
}
- (void)viewWillAppear:(BOOL)arg1
{
	%orig;
	[self _reloadData];
}
%new
- (void)refresh:(UIRefreshControl *)refresh
{
	firstTimeOnlyShowReloadApps = YES;
	[(InstalledController*)self _reloadData];
	if(refresh) {
		[refresh endRefreshing];
	}	
}
- (void)reinstallButtonClicked
{
	if(LSApplicationProxy* lsAppProxy = [LSApplicationProxy applicationProxyForIdentifier:[[NSBundle mainBundle] bundleIdentifier]]) {
		if(![lsAppProxy profileValidated]) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Extendlife" message:@"Cydia Extender is Currently installed without provisioning profile, Resign of app \"Cydia Extender\" is currently disabled in this mode. if you want sideloadable do it manually.\n\nNOTE: Resign Installed Application will not work if sideload \"Cydia Extender\" because of sandbox protection." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];[alert show];
			return;
		}
	}
	%orig;
}
%new
- (void)reinstallAllButtonClicked
{
	if([getAllMails() count] == 0) {
		showBanner(@"Please, Setup Apple Account In Ex3nder", YES);
		return;
	}
	if(!isNetworkReachable()) {
		showBanner([[NSBundle mainBundle] localizedStringForKey:@"NETWORK_ERROR" value:@"Network Error" table:nil], YES);
		return;
	}
	
	UIActivityIndicatorView* activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleGray];
	activityView.frame = CGRectMake(0, 0, 25, 25);
	[activityView sizeToFit];
	[activityView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)];
	UIBarButtonItem *loadingView = [[UIBarButtonItem alloc] initWithCustomView:activityView];
	((UIViewController*)self).navigationItem.leftBarButtonItems = @[loadingView];
	[activityView startAnimating];
	
	revokeResignAll();
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static __strong NSString* simpleTableIdentifier = @"Ext3nder";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:simpleTableIdentifier];
	}
	
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	[cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
	
	cell.accessoryView = nil;
	cell.imageView.image = nil;
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	cell.textLabel.textColor = [UIColor blackColor];
	cell.detailTextLabel.textColor = [UIColor grayColor];
	
	cell.textLabel.font = [UIFont systemFontOfSize:18];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:10];
	
	cell.textLabel.numberOfLines = 0;
	cell.detailTextLabel.numberOfLines = 0;
	
	cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
	cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
	
	@try{
	if(NSMutableArray* appToShow = (NSMutableArray *)object_getIvar(self, class_getInstanceVariable([self class], "proxies_"))) {
		LSApplicationProxy* indexProxy = appToShow[indexPath.row];
		
		cell.imageView.image = [UIImage _applicationIconImageForBundleIdentifier:indexProxy.applicationIdentifier format:0 scale:[UIScreen mainScreen].scale];
		cell.textLabel.text = [indexProxy localizedName];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@: ", [[NSBundle mainBundle] localizedStringForKey:@"VERSION" value:@"Version" table:nil]];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@", indexProxy.shortVersionString]];
		
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:@"\n"];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@: ", @"Size"]];		
		static __strong NSString* kKB = [[[NSBundle bundleWithPath:@"/System/Library/Frameworks/Foundation.framework"] localizedStringForKey:@"%.1f KB (1.0)" value:@"%.1f KB" table:@"URL"]?:@"%.1f KB" copy];//@"%.f KB";
		static __strong NSString* kMB = [[[NSBundle bundleWithPath:@"/System/Library/Frameworks/Foundation.framework"] localizedStringForKey:@"%.1f MB (1.0)" value:@"%.1f MB" table:@"URL"]?:@"%.1f MB" copy];//@"%.1f MB";		
		float sizeFloat = [indexProxy.staticDiskUsage floatValue];		
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@", [NSString stringWithFormat:sizeFloat>=1048576?kMB:kKB, sizeFloat>=1048576?(float)sizeFloat/1048576:(float)sizeFloat/1024]]];
		
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:@"\n"];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@: ", @"Bundle"]];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@", indexProxy.applicationIdentifier]];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:@"\n"];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@: ", [[NSBundle mainBundle] localizedStringForKey:@"INSTALLED" value:@"Installed" table:nil]]];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@", timeIntervalStringFromDate([NSDate dateWithTimeIntervalSinceReferenceDate:indexProxy.bundleModTime], YES)]];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:@"\n"];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@: ", @"Provision Valid"]];
		if(indexProxy.profileValidated) {
			if(NSDictionary* dicProvision = provisionDicFromBundleID(indexProxy.applicationIdentifier)) {
				if(NSDate* validateDate = dicProvision[@"ExpirationDate"]) {
					cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@", timeIntervalStringFromDate(validateDate, NO)]];
				}
			}
		} else {
			cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@", [[NSBundle mainBundle] localizedStringForKey:@"NO" value:nil table:nil]]];
		}
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:@"\n"];
		cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@", indexProxy.signerIdentity]];
		
		
		if([indexProxy profileValidated]&&indexProxy.teamID&&[getAllTeams() containsObject:indexProxy.teamID]) {
			cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:@"\n"];
			cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingString:[NSString stringWithFormat:@"%@: ", @"Sign Status"]];
			if(currentBundleID&&[currentBundleID isEqualToString:indexProxy.applicationIdentifier]) {
				cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%@ %@", @"♻️", [[NSBundle mainBundle] localizedStringForKey:@"LOADING" value:@"Loading" table:nil]];
			} else if([installedBundleIdForResign containsObject:indexProxy.applicationIdentifier]) {
				cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%@ %@", @"🔰", [[NSBundle mainBundle] localizedStringForKey:@"Q_D" value:@"Queued" table:nil]];
			} else {
				if(NSDictionary* dicProvision = provisionDicFromBundleID(indexProxy.applicationIdentifier)) {
					if(NSDate* validateDate = dicProvision[@"ExpirationDate"]) {
						int daysLeft = daysFromDate(validateDate);
						NSLog(@"Date: %@ -- daysLeft %d", validateDate, daysLeft);
						if(NSDate* revokedDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"revokedDate"]) {
							if(NSDate* creationDate = dicProvision[@"CreationDate"]) {
								if([revokedDate timeIntervalSince1970] > [creationDate timeIntervalSince1970]) {
									daysLeft = 0;
								}
							}
						}
						if(daysLeft == 0) {
							cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%@ %@", @"⛔️", [[NSBundle mainBundle] localizedStringForKey:@"WARNING" value:@"Warning" table:nil]];
						} else if(!(daysLeft > DaysLeftResign)) {
							cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%@ %@", @"⚠️", @"Need Resign"];
						} else {
							cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%@ %@", @"✅", [[NSBundle mainBundle] localizedStringForKey:@"SAFE" value:@"Safe" table:nil]];
						}
					} else {
						cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%@ %@", @"⛔️", [[NSBundle mainBundle] localizedStringForKey:@"WARNING" value:@"Warning" table:nil]];
					}
				} else {
					cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%@ %@", @"⛔️", [[NSBundle mainBundle] localizedStringForKey:@"WARNING" value:@"Warning" table:nil]];
				}
			}
		}
	}
	} @catch(NSException* ex) {
		return cell;
	}
	
	return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	@try {
		if(NSMutableArray* appToShow = (NSMutableArray *)object_getIvar(self, class_getInstanceVariable([self class], "proxies_"))) {
			return [appToShow count];
		}
	} @catch(NSException* ex) {
		return 0;
	}
    return 0;
}
%new
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	@try {
	LSApplicationProxy* appProxy = [self proxyAtIndexPath:indexPath];
	
	UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:[appProxy localizedName] delegate:(id<UIActionSheetDelegate>)self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
	[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Open Link" value:@"Open" table:nil]?:@"Open"];
	[popup addButtonWithTitle:@"Resign"];
	if([getAllMails() count] > 1) {
		[popup addButtonWithTitle:@"Resign With Account..."];
	}
	[popup addButtonWithTitle:@"Rebuild To .ipa"];
	[popup setDestructiveButtonIndex:[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Delete" value:@"Delete" table:nil]?:@"Delete"]];
	[popup addButtonWithTitle:[[NSBundle mainBundle] localizedStringForKey:@"CANCEL" value:nil table:nil]];
	[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
	popup.tag = indexPath.row;
	if (isDeviceIPad) {
		[popup showFromBarButtonItem:[[((UIViewController*)self) navigationItem] rightBarButtonItem] animated:YES];
	} else {
		[popup showInView:((UIViewController*)self).view];
	}
	} @catch(NSException* ex) {
	}
	return nil;
}
%new
- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
	if (button == [alert cancelButtonIndex]) {
	} else if  (button == [alert destructiveButtonIndex]) {
		[self tableView:(UITableView *)self commitEditingStyle:(UITableViewCellEditingStyle)0 forRowAtIndexPath:[NSIndexPath indexPathForRow:alert.tag inSection:0]];
	} else if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Open Link" value:@"Open" table:nil]?:@"Open"]) {
		LSApplicationWorkspace *workspace = [LSApplicationWorkspace performSelector:@selector(defaultWorkspace)];
		[workspace openApplicationWithBundleID:[[self proxyAtIndexPath:[NSIndexPath indexPathForRow:alert.tag inSection:0]] applicationIdentifier]];
	} else if ([buttonTitle isEqualToString:@"Resign"]) {
		resignForAppProxy([self proxyAtIndexPath:[NSIndexPath indexPathForRow:alert.tag inSection:0]], NO, nil);
	} else if ([buttonTitle isEqualToString:@"Resign With Account..."]) {
		UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:[[self proxyAtIndexPath:[NSIndexPath indexPathForRow:alert.tag inSection:0]] localizedName] delegate:(id<UIActionSheetDelegate>)self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		popup.tag = alert.tag;
		for(NSString* emailStNow in getAllMails()) {
			[popup addButtonWithTitle:emailStNow];
		}
		[popup addButtonWithTitle:[[NSBundle mainBundle] localizedStringForKey:@"CANCEL" value:nil table:nil]];
		[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
		if (isDeviceIPad) {
			[popup showFromBarButtonItem:[[((UIViewController*)self) navigationItem] rightBarButtonItem] animated:YES];
		} else {
			[popup showInView:((UIViewController*)self).view];
		}
	} else if ([buttonTitle isEqualToString:@"Rebuild To .ipa"]) {
		repackSaveForAppProxy([self proxyAtIndexPath:[NSIndexPath indexPathForRow:alert.tag inSection:0]]);
	} else if ([buttonTitle rangeOfString:@"@"].location != NSNotFound) {
		resignForAppProxy([self proxyAtIndexPath:[NSIndexPath indexPathForRow:alert.tag inSection:0]], NO, buttonTitle);
	}	
	[alert dismissWithClickedButtonIndex:0 animated:YES];
}
%new
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return	YES;
}
%new
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	LSApplicationProxy* appProxy = [self proxyAtIndexPath:indexPath];
	NSString* appName = [[appProxy localizedName] copy];
	NSString* idUn = [appProxy.applicationIdentifier copy];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		@try {
			isInProgress = YES;
			queueAlertBar([@"Uninstalling " stringByAppendingString:appName]);
			LSApplicationWorkspace *workspace = [LSApplicationWorkspace performSelector:@selector(defaultWorkspace)];
			[workspace uninstallApplication:idUn withOptions:nil];
			queueAlertBar([@"Uninstalled " stringByAppendingString:appName]);
			isInProgress = NO;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/appChanged" object:nil];
		} @catch(NSException* ex) {
		}
	});
}
%new
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	@try {
		UITableViewCell *cell = (UITableViewCell*)[self tableView:tableView cellForRowAtIndexPath:indexPath];
		CGSize size = [cell.textLabel.text sizeWithFont:cell.textLabel.font constrainedToSize:CGSizeMake(130, 1500) lineBreakMode:NSLineBreakByWordWrapping];
		CGSize size2 = [cell.detailTextLabel.text sizeWithFont:cell.detailTextLabel.font constrainedToSize:CGSizeMake(130, 1500) lineBreakMode:NSLineBreakByWordWrapping];
		return size.height + size2.height;
	} @catch(NSException* ex) {
		return 40;
	}
	return 40;
}
%end

%hook CyextTabBarController
- (void)setViewControllers:(NSArray*)arg1
{
	NSMutableArray *controllers([arg1 mutableCopy]);
	
	UITabBarItem *item = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemDownloads tag:0];
	UINavigationController *controller([[UINavigationController alloc] init]);
	[controller setTabBarItem:item];
	[controllers addObject:controller];
	
	UITabBarItem *item0 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:0];
	UINavigationController *controller0([[UINavigationController alloc] init]);
	[item0 _setInternalTitle:[[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/ManagedConfigurationUI.bundle"] localizedStringForKey:@"PLURAL_BLOBS_DESIGNATION" value:@"Profiles" table:@"ManagedConfigurationUI"]];
	[controller0 setTabBarItem:item0];
	[controllers addObject:controller0];
	
	UITabBarItem *item2 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMore tag:0];
	UINavigationController *controller2([[UINavigationController alloc] init]);
	[controller2 setTabBarItem:item2];
	[controllers addObject:controller2];
	
	%orig(controllers);
}
%end



%hook UIAlertController
- (void)_logBeingPresented
{
	if((emailSt||passSt)&&[(UIAlertController*)self title]&&[[(UIAlertController*)self title] isEqualToString:@"Apple Developer"]&&[(UIAlertController*)self message]&&[[(UIAlertController*)self message] isEqualToString:@"Your password is only sent to Apple."]) {
		if([(UIAlertController*)self textFields]&&[[(UIAlertController*)self textFields] count] > 1) {
			UITextField* emailField = [(UIAlertController*)self textFields][0];
			UITextField* passField = [(UIAlertController*)self textFields][1];
			emailField.text = [emailSt copy];
			passField.text = [getPassForEmail(emailSt)?:passSt?:@"" copy];
			if(emailField.text.length > 1 && passField.text.length > 1 && [(UIAlertController*)self actions] && [[(UIAlertController*)self actions] count] > 1) {
				((UIAlertController*)self).view.hidden = YES;
				for(id actionNow in [(UIAlertController*)self actions]) {
					if(actionNow == [(UIAlertController*)self cancelAction]) {
						continue;
					}
					if(showAuthenticationNotification) {
						showBanner([@"Apple Account Authenticated: " stringByAppendingString:emailField.text], NO);
					}
					[(UIAlertController*)self _dismissWithAction:actionNow];
					break;
				}				
			}
		}
	} else if ([(UIAlertController*)self title]&&[[(UIAlertController*)self title] isEqualToString:[[NSBundle mainBundle] localizedStringForKey:@"ERROR" value:@"ERROR" table:nil]]) {
		errorCount++;
		((UIAlertController*)self).view.hidden = YES;
		showBanner([(UIAlertController*)self message], YES);
		for(id actionNow in [(UIAlertController*)self actions]) {
			[(UIAlertController*)self _dismissWithAction:actionNow];
			break;
		}
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			if(isInLoopPackage) {
				allowMeToInstallIpaInLoop = YES;
				[(Extender*)[UIApplication sharedApplication] application:[UIApplication sharedApplication] openURL:lastIpaUrlFilePath sourceApplication:[UIApplication sharedApplication] annotation:nil];
				allowMeToInstallIpaInLoop = NO;
			}
		});
    }
	%orig;
}
%end


%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
{
    if ([[url path] rangeOfString:@"debug.txt"].location != NSNotFound) {
        completionHandler([NSData dataWithBytes:" " length:1], nil, nil);
        return nil;
    } else {
        return %orig(url, completionHandler);
    }
}
%end


static void settingsChangedExtendlife(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{	
	@autoreleasepool {
		oldMessage = nil;
		
		if(NSString *teamIDValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"myTeamID"]) {
			if(teamIDValue.length > 1) {
				myTeamID = teamIDValue.UTF8String;
			}
		}
		
		if(NSString *emailStValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"SaveMail"]) {
			if(emailStValue.length > 1) {
				emailSt = emailStValue;
			}			
		}
		if(NSString *passStValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"SavePass"]) {
			if(passStValue.length > 1) {
				passSt = passStValue;
			}
		}
		
		preferredEmail = [[NSUserDefaults standardUserDefaults] objectForKey:@"preferredEmail"];
		
		deviceUdid = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceUdid"];
		if(deviceUdid==nil || (deviceUdid&&deviceUdid.length!=40)) {
			deviceUdid = [NSString stringWithFormat:@"%@", MGCopyAnswer(CFSTR("UniqueDeviceID"))];
			if(deviceUdid&&deviceUdid.length!=40) {
				deviceUdid = nil;
			}
			if(deviceUdid) {
				[[NSUserDefaults standardUserDefaults] setObject:deviceUdid forKey:@"deviceUdid"];
				[[NSUserDefaults standardUserDefaults] synchronize];
				deviceUdid = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceUdid"];
			}
		}

		deviceName = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceName"];
		if(deviceName==nil || (deviceName&&deviceName.length==0)) {
			AADeviceInfo* deviceInfo = [[AADeviceInfo alloc] init];
			if(NSString* deviceNameValue = [deviceInfo deviceName]) {
				[[NSUserDefaults standardUserDefaults] setObject:deviceNameValue forKey:@"deviceName"];
				[[NSUserDefaults standardUserDefaults] synchronize];
				deviceName = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceName"];
			} else {
				deviceName = nil;
			}
		}
		
		allowCydiaSubstrate = [[[NSUserDefaults standardUserDefaults] objectForKey:@"allowCydiaSubstrate"]?:@YES boolValue];
		disableVPN = [[[NSUserDefaults standardUserDefaults] objectForKey:@"disableVPN"]?:@YES boolValue];
		showUserApp = [[[NSUserDefaults standardUserDefaults] objectForKey:@"showUserApp"]?:@NO boolValue];
		saveSignedApp = [[[NSUserDefaults standardUserDefaults] objectForKey:@"saveSignedApp"]?:@NO boolValue];
		BackgroundTranslucent = [[[NSUserDefaults standardUserDefaults] objectForKey:@"BackgroundTranslucent"]?:@NO boolValue];
		showAuthenticationNotification = [[[NSUserDefaults standardUserDefaults] objectForKey:@"showAuthenticationNotification"]?:@YES boolValue];
		showRevokeNotification = [[[NSUserDefaults standardUserDefaults] objectForKey:@"showRevokeNotification"]?:@YES boolValue];
		fastZipCompression = [[[NSUserDefaults standardUserDefaults] objectForKey:@"fastZipCompression"]?:@YES boolValue];
		AutoSignEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AutoSignEnabled"]?:@NO boolValue];
		DaysLeftResign = (int)[[[NSUserDefaults standardUserDefaults] objectForKey:@"DaysLeftResign"]?:@(2) intValue];
		notificationAlerts = [[[NSUserDefaults standardUserDefaults] objectForKey:@"notificationAlerts"]?:@YES boolValue];
		notificationErrors = [[[NSUserDefaults standardUserDefaults] objectForKey:@"notificationErrors"]?:@YES boolValue];
	}
}


extern "C" size_t strlen(const char *str)
{
	if(!disableTemp &&str&&myTeamID&&origTeamID&&strcmp(str, origTeamID)==0) {
		memcpy((void*)str, (const void *)myTeamID, 10);
	}
	size_t(*strlen)(const char *) = (size_t(*)(const char *))(dlsym(RTLD_NEXT, "strlen"));
	return strlen(str);
}


extern "C" int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize)
{
	int(*csops)(pid_t, unsigned int, void *, size_t) = (int(*)(pid_t, unsigned int, void *, size_t))(dlsym(RTLD_NEXT, "csops"));
	int ret = csops(pid, ops, useraddr, usersize);
	if(myTeamID&&origTeamID) {
		char* str =(char*)useraddr;
		void * pch = memmem((const void*)str, usersize, origTeamID, 10);
		if(pch!=NULL) {
			memcpy(pch, myTeamID,10);
		}
	}	
	return ret;
}




#import <Security/Security.h>
static CFDictionaryRef fixMeForKeychain(CFDictionaryRef attributes)
{
	if(attributes) {
		NSMutableDictionary* mutAttributes = [(NSDictionary*)attributes mutableCopy];
		mutAttributes[(id)kSecAttrAccessible] = (id)kSecAttrAccessibleAlways;
		if(id SecAttrtAc = mutAttributes[(id)kSecAttrAccount]) {
			mutAttributes[(id)kSecAttrAccount] = [NSString stringWithFormat:@"%@-%s", SecAttrtAc, myTeamID];
		}
		if(id SecAttrtSe = mutAttributes[(id)kSecAttrService]) {
			mutAttributes[(id)kSecAttrService] = [NSString stringWithFormat:@"%@-%s", SecAttrtSe, myTeamID];
		}		
		attributes = (CFDictionaryRef)mutAttributes;
	}
	return attributes;
}
extern "C" OSStatus SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result)
{
	attributes = fixMeForKeychain(attributes);
	OSStatus(*SecItemAdd)(CFDictionaryRef, CFTypeRef *) = (OSStatus(*)(CFDictionaryRef, CFTypeRef *))(dlsym(RTLD_NEXT, "SecItemAdd"));
	return SecItemAdd(attributes, result);
}
extern "C" OSStatus SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate)
{
	query = fixMeForKeychain(query);
	attributesToUpdate = fixMeForKeychain(attributesToUpdate);
	OSStatus(*SecItemUpdate)(CFDictionaryRef, CFDictionaryRef) = (OSStatus(*)(CFDictionaryRef, CFDictionaryRef))(dlsym(RTLD_NEXT, "SecItemUpdate"));
	return SecItemUpdate(query, attributesToUpdate);
}
extern "C" OSStatus SecItemDelete(CFDictionaryRef query)
{
	query = fixMeForKeychain(query);
	OSStatus(*SecItemDelete)(CFDictionaryRef) = (OSStatus(*)(CFDictionaryRef))(dlsym(RTLD_NEXT, "SecItemDelete"));
	return SecItemDelete(query);
}
extern "C" OSStatus SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result)
{
	query = fixMeForKeychain(query);
	OSStatus(*SecItemCopyMatching)(CFDictionaryRef, CFTypeRef*) = (OSStatus(*)(CFDictionaryRef, CFTypeRef*))(dlsym(RTLD_NEXT, "SecItemCopyMatching"));
	return SecItemCopyMatching(query, result);
}


static int (*deflateInit2__orig)(z_streamp strm, int level, int method, int windowBits, int memLevel, int strategy, const char *version, int stream_size);
static int deflateInit2__rep(z_streamp strm, int level, int method, int windowBits, int memLevel, int strategy, const char *version, int stream_size)
{
	level = fastZipCompression?Z_NO_COMPRESSION:Z_DEFAULT_COMPRESSION;
	return deflateInit2__orig(strm, level, method, windowBits, memLevel, strategy, version, stream_size);
}

typedef const struct _CFURLConnection *CFURLConnectionRef;
typedef const struct _CFURLRequest *CFURLRequestRef;
typedef const struct CFURLConnectionClient_V1 CFURLConnectionClient;
extern "C" CFURLRef CFURLRequestGetURL(CFURLRequestRef request);
static CFURLConnectionRef (*CFURLConnectionCreateWithProperties_orig)(CFAllocatorRef alloc, CFURLRequestRef request, CFURLConnectionClient* client, CFDictionaryRef properties);
static CFURLConnectionRef CFURLConnectionCreateWithProperties_rep(CFAllocatorRef alloc, CFURLRequestRef request, CFURLConnectionClient* client, CFDictionaryRef properties)
{
	if(request) {
		CFURLRef urlCf = CFURLRequestGetURL(request);
		NSString* urlSt = [NSString stringWithFormat:@"%@", CFURLGetString(urlCf)];
		if([urlSt rangeOfString:@"apple.com/"].location != NSNotFound) {
			NSURL* urlNs = [NSURL URLWithString:urlSt];
			queueAlertBar([[@"/" stringByAppendingPathComponent:[urlNs lastPathComponent]?:@""] copy]);
		}
		//NSLog(@"*** CFURLConnectionCreateWithProperties_rep[%@]", urlSt);
	}
	return CFURLConnectionCreateWithProperties_orig(alloc, request, client, properties);
}

static void (*CFHTTPMessageSetBody_orig)(CFHTTPMessageRef message, CFDataRef bodyData);
static void CFHTTPMessageSetBody_rep(CFHTTPMessageRef message, CFDataRef bodyData)
{
	if(bodyData) {
		NSMutableData* data = [(NSData*)bodyData copy];
		NSString* newStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		newStr = [newStr stringByReplacingOccurrencesOfString:@"userLocale=en_US" withString:[NSString stringWithFormat:@"userLocale=%@", currentLocaleId()]];
		newStr = [newStr stringByReplacingOccurrencesOfString:@"<string>en_US</string>" withString:[NSString stringWithFormat:@"<string>%@</string>", currentLocaleId()]];
		//newStr = [newStr stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%s", origTeamID] withString:[NSString stringWithFormat:@"%s", myTeamID]];
		bodyData = (CFDataRef)[newStr dataUsingEncoding:NSUTF8StringEncoding];
	}
	//NSLog(@"*** CFHTTPMessageSetBody: %@", bodyData);
	return CFHTTPMessageSetBody_orig(message, bodyData);
}




static void *dlopen_r(const char *filename, int flag)
{
	if(filename && (strlen(filename)>41) && (strstr(filename, "/Library/MobileSubstrate/DynamicLibraries")!= NULL)) {
		//flag |= RTLD_NOLOAD;
		filename = "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate";
	}
	return dlopen(filename, flag);
}
DYLD_INTERPOSE(dlopen_r, dlopen)


__attribute__((constructor)) static void initialize_Extendlife()
{	
	@autoreleasepool {
		if (strcmp(__progname, "Extender") == 0) {
			
			preventSystemSleep();
			
			notify_post("com.julioverne.ext3nder/Launched");
			
			dlopen("/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension", RTLD_GLOBAL);
			dlopen("/System/Library/PreferenceBundles/ManagedConfigurationUI.bundle/ManagedConfigurationUI", RTLD_GLOBAL);
			
			
			dlopen("/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate", RTLD_GLOBAL);
			void(*MSHookFunctions)(void *, void *, void **) = (void(*)(void *, void *, void **))(dlsym(RTLD_DEFAULT, "MSHookFunction"));
			if(MSHookFunctions != NULL) {
				MSHookFunctions((void *)(dlsym(RTLD_DEFAULT, "deflateInit2_")), (void *)deflateInit2__rep, (void **)&deflateInit2__orig);
				MSHookFunctions((void *)(dlsym(RTLD_DEFAULT, "CFURLConnectionCreateWithProperties")), (void *)CFURLConnectionCreateWithProperties_rep, (void **)&CFURLConnectionCreateWithProperties_orig);
				MSHookFunctions((void *)(dlsym(RTLD_DEFAULT, "CFHTTPMessageSetBody")), (void *)CFHTTPMessageSetBody_rep, (void **)&CFHTTPMessageSetBody_orig);
			}
			
			
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChangedExtendlife, CFSTR("com.julioverne.extendlife/Settings"), NULL, CFNotificationSuspensionBehaviorCoalesce);
			settingsChangedExtendlife(NULL, NULL, NULL, NULL, NULL);
			
			
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, stateChangedExt3nder, CFSTR("com.julioverne.ext3nder.status"), NULL, CFNotificationSuspensionBehaviorCoalesce);

			disableTemp = YES;
			NSDictionary *query = [[NSDictionary dictionaryWithObjectsAndKeys:
			   (id)kSecClassGenericPassword, (id)kSecClass,
			   @"bundleSeedID", kSecAttrAccount,
			   @"", kSecAttrService,
			   (id)kCFBooleanTrue, kSecReturnAttributes,
			   nil] copy];
			CFDictionaryRef result = nil;
			OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
			if(status == errSecItemNotFound) {
				status = SecItemAdd((CFDictionaryRef)query, (CFTypeRef *)&result);
			}
			if(status == errSecSuccess) {
				NSString *accessGroup = [(NSDictionary *)result objectForKey:(id)kSecAttrAccessGroup];
				NSArray *components = [accessGroup componentsSeparatedByString:@"."];
				NSString *AppIdentifierPrefix = [[components objectEnumerator] nextObject];
				teamID = [AppIdentifierPrefix copy];
				origTeamID = (const char*)(malloc(11));
				memcpy((void*)origTeamID,(const void*)AppIdentifierPrefix.UTF8String, 10);
				((char*)origTeamID)[11] = '\0';
				disableTemp = NO;
			}
			
			
			setNowWorkingEmail(getEmailForTeam(nil));
		}
	}
}



