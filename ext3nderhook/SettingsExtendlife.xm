#import "Extendlife.h"

/*
static __strong NSMutableDictionary* credentialCaches = [[NSMutableDictionary alloc] init];
static NSTimeInterval credentialCacheValidUntil;
static void checkCredentialValid()
{
	if(credentialCacheValidUntil==0 || (credentialCacheValidUntil!=0 && (credentialCacheValidUntil < [[NSDate date] timeIntervalSince1970]))) {
		credentialCaches = [[NSMutableDictionary alloc] init];
		credentialCacheValidUntil = [[NSDate date] timeIntervalSince1970] + 300; // 5min
	}
}
static NSDictionary* credentialForMail(NSString* forMail)
{
	checkCredentialValid();
	return credentialCaches[forMail];
}
static void saveCredentialForMail(NSString* forMail, NSDictionary* credential)
{
	checkCredentialValid();
	credentialCaches[forMail] = credential;
}
*/



extern BOOL BackgroundTranslucent;
extern BOOL showRevokeNotification;
extern NSMutableArray* recentInstalledBundleIDAfterRevoke;


static NSString* urlEncodeUsingEncoding(NSString* encoding)
{
	return (NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)encoding, NULL, CFSTR("!*'\"();:@&=+$,/?%#[] "), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}
static void saveAppleAccountInfo(NSString* emailSt, NSString* passSt, NSString* teamSt)
{
	@autoreleasepool {
		NSData* encriptedPass = AES128Ex([passSt dataUsingEncoding:NSASCIIStringEncoding], YES, @"\x01\x00\x07\x08\x00\x04\x03", nil);
		NSMutableDictionary* accountLibrary = [accountLibraryDic()?:[NSDictionary dictionary] mutableCopy];
		accountLibrary[emailSt] = @{@"pass":encriptedPass, @"team": teamSt};
		[[NSUserDefaults standardUserDefaults] setObject:accountLibrary forKey:@"accountLibrary"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SavePass"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SaveMail"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"myTeamID"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		notify_post("com.julioverne.extendlife/Settings");
		[[SettingsExtendlife shared] performSelector:@selector(refresh:) withObject:nil afterDelay:0.4f];
		showBanner([NSString stringWithFormat:@"Success, Account \"%@\" Saved To Library.. Password Is Encrypted With AES128.", emailSt], NO);
	}
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
@implementation SettingsExtendlife
+ (id) shared {
	static __strong SettingsExtendlife* SettingsExtendlifeC;
	if (!SettingsExtendlifeC) {
		SettingsExtendlifeC = [[self alloc] init];
	}
	return SettingsExtendlifeC;
}
- (id)readOriginalTeamIDValue:(id)arg1
{
	return teamID;
}
- (id)readCurrentTeamIDValue:(id)arg1
{
	return myTeamID?[NSString stringWithUTF8String:myTeamID]:teamID;
}
- (id)specifiers {
	if (!_specifiers) {
		NSMutableArray* specifiers = [NSMutableArray array];
		PSSpecifier* spec;
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Revoke Certificates"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Revoke Certificates" forKey:@"label"];
		[spec setProperty:@"Used if show error about already exist or pending Certificate, Can be used for reset time left in provision profile." forKey:@"footerText"];
		[specifiers addObject:spec];
			spec = [PSSpecifier preferenceSpecifierNamed:@"Revoke All Certificates Now"
					      target:self
						 set:NULL
						 get:NULL
					      detail:Nil
						cell:PSButtonCell
						edit:Nil];
	spec->action = @selector(revokeAllKnowsAccounts);
	[spec setProperty:NSClassFromString(@"SSTintedCell") forKey:@"cellClass"];
	[specifiers addObject:spec];
	spec = [PSSpecifier preferenceSpecifierNamed:@"Show Notification"
						  target:self
												 set:@selector(setAccountValue:specifier:)
												 get:@selector(readAccountValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
			[spec setProperty:@"showRevokeNotification" forKey:@"key"];
			[spec setProperty:@YES forKey:@"default"];
		[specifiers addObject:spec];
		
	
		spec = [PSSpecifier preferenceSpecifierNamed:@"Delete App ID"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Delete App ID" forKey:@"label"];
		[spec setProperty:@"List All App's ID by Account and Delete Selected." forKey:@"footerText"];
		[specifiers addObject:spec];
			spec = [PSSpecifier preferenceSpecifierNamed:@"Manage App's ID"
					      target:self
						 set:NULL
						 get:NULL
					      detail:Nil
						cell:PSButtonCell
						edit:Nil];
	spec->action = @selector(promptListAppIDs);
	[spec setProperty:NSClassFromString(@"SSTintedCell") forKey:@"cellClass"];
	[specifiers addObject:spec];
	
		/*
		spec = [PSSpecifier preferenceSpecifierNamed:@"Set/Change TeamID"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Set/Change TeamID" forKey:@"label"];
		[spec setProperty:@"Set your Apple Account TeamID.\nTeamID is Spoofed at runtime, don't change files." forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Original TeamID"
					      target:self
						 set:NULL
						 get:@selector(readOriginalTeamIDValue:)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[spec setProperty:@"OriginalTeamID" forKey:@"key"];
		[spec setProperty:teamID forKey:@"default"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Current TeamID"
					      target:self
						 set:NULL
						 get:@selector(readCurrentTeamIDValue:)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[spec setProperty:@"CurrentTeamID" forKey:@"key"];
		[spec setProperty:myTeamID?[NSString stringWithUTF8String:myTeamID]:teamID forKey:@"default"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"TeamID:"
					      target:self
											  set:@selector(setCurrentTeamIDValue:specifier:)
											  get:@selector(readValue:)
					      detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:@"TeamID" forKey:@"key"];
		[specifiers addObject:spec];
			spec = [PSSpecifier preferenceSpecifierNamed:@"I Don't Know (via Login Apple)"
					      target:self
						 set:NULL
						 get:NULL
					      detail:Nil
						cell:PSButtonCell
						edit:Nil];
	spec->action = @selector(getTeamID);
	[spec setProperty:NSClassFromString(@"SSTintedCell") forKey:@"cellClass"];
	[specifiers addObject:spec];
	*/
		spec = [PSSpecifier preferenceSpecifierNamed:@"Setup Login Apple"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Save Login Apple" forKey:@"label"];
		[spec setProperty:@"Save To Account Library With Protection AES128, Account With Two-Factor Authentication Is Incompatible." forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Email:"
					      target:self
											  set:@selector(setAccountValue:specifier:)
											  get:@selector(readAccountValue:)
					      detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:@"SaveMail" forKey:@"key"];
		[spec setProperty:@YES forKey:@"isEmail"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Password:"
					      target:self
											  set:@selector(setAccountValue:specifier:)
											  get:@selector(readAccountValue:)
					      detail:Nil
											  cell:PSSecureEditTextCell
											  edit:Nil];
		[spec setProperty:@"SavePass" forKey:@"key"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Setup Login To Library"
					      target:self
						 set:NULL
						 get:NULL
					      detail:Nil
						cell:PSButtonCell
						edit:Nil];
		spec->action = @selector(saveAccount_bt);
		[spec setProperty:NSClassFromString(@"SSTintedCell") forKey:@"cellClass"];
		[specifiers addObject:spec];
		
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Account's Manager"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Account's Manager" forKey:@"label"];
		[spec setProperty:@"Manage Multiples Apple Account's" forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Account Library"
					      target:self
											  set:@selector(setAccountLibraryValue:specifier:)
											  get:@selector(readAccountLibraryValue:)
					      detail:PSListItemsController.class
											  cell:PSLinkListCell
											  edit:Nil];
			[spec setProperty:@"preferredEmail" forKey:@"key"];
			NSDictionary* accountLibrary = accountLibraryDic()?:[NSDictionary dictionary];
			NSArray* allMail = [accountLibrary allKeys];
			[spec setProperty:@"" forKey:@"default"];
			[spec setValues:allMail titles:allMail];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Show Notification"
						  target:self
												 set:@selector(setAccountValue:specifier:)
												 get:@selector(readAccountValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
			[spec setProperty:@"showAuthenticationNotification" forKey:@"key"];
			[spec setProperty:@YES forKey:@"default"];
		[specifiers addObject:spec];
		
	
	
	spec = [PSSpecifier preferenceSpecifierNamed:@"Auto Signer IPA"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Auto Signer IPA" forKey:@"label"];
		[spec setProperty:@"Resign All & Sign All .ipa File From Folder \"AutoSign\".\n\nRequires Account Stored In \"Account Library\".\n\nFor test delete app from homescreen, respring and wait.\n" forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
						  target:self
												 set:@selector(setAccountValue:specifier:)
												 get:@selector(readAccountValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
			[spec setProperty:@"AutoSignEnabled" forKey:@"key"];
			[spec setProperty:@NO forKey:@"default"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Resign When Missing"
					      target:self
											  set:@selector(setAccountValue:specifier:)
											  get:@selector(readAccountValue:)
					      detail:PSListItemsController.class
											  cell:PSLinkListCell
											  edit:Nil];
			[spec setProperty:@"DaysLeftResign" forKey:@"key"];
			[spec setProperty:@2 forKey:@"default"];
			[spec setValues:@[@1, @2, @3, @4, @5, @6]
			titles:@[ [NSString stringWithFormat:@"%d Days", 1],
					  [NSString stringWithFormat:@"%d Days", 2],
					  [NSString stringWithFormat:@"%d Days", 3],
					  [NSString stringWithFormat:@"%d Days", 4],
					  [NSString stringWithFormat:@"%d Days", 5],
					  [NSString stringWithFormat:@"%d Days", 6]]];
		[specifiers addObject:spec];
			spec = [PSSpecifier preferenceSpecifierNamed:@"Check Every"
					      target:self
											  set:@selector(setAccountValue:specifier:)
											  get:@selector(readAccountValue:)
					      detail:PSListItemsController.class
											  cell:PSLinkListCell
											  edit:Nil];
			[spec setProperty:@"intervalCheck" forKey:@"key"];
			[spec setProperty:@7200 forKey:@"default"];
			[spec setValues:@[@1800, @3600, @7200, @10800, @14400, @18000, @43200]
			titles:@[ [NSString stringWithFormat:@"%d Minutes", 30],
					  [NSString stringWithFormat:@"%d Hour", 1],
					  [NSString stringWithFormat:@"%d Hours", 2],
					  [NSString stringWithFormat:@"%d Hours", 3],
					  [NSString stringWithFormat:@"%d Hours", 4],
					  [NSString stringWithFormat:@"%d Hours", 5],
					  [NSString stringWithFormat:@"%d Hours", 12]]];
		[specifiers addObject:spec];
		
	spec = [PSSpecifier preferenceSpecifierNamed:@"Activator"
		                                      target:self
											  set:Nil
											  get:Nil
                                              detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Activator" forKey:@"label"];
		[spec setProperty:@"Action For Revoke And Resign All." forKey:@"footerText"];
        [specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Activation Method"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
		if (access("/usr/lib/libactivator.dylib", F_OK) == 0) {
			[spec setProperty:@YES forKey:@"isContoller"];
			[spec setProperty:@"com.julioverne.ext3nder" forKey:@"activatorListener"];
			[spec setProperty:@"/System/Library/PreferenceBundles/LibActivator.bundle" forKey:@"lazy-bundle"];
			spec->action = @selector(lazyLoadBundle:);
		}
        [specifiers addObject:spec];
		
	spec = [PSSpecifier preferenceSpecifierNamed:@"Save Signed IPA"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Save Signed IPA" forKey:@"label"];
		[spec setProperty:@"Save Signed IPA File To 'Signed' Folder." forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
						  target:self
												 set:@selector(setAccountValue:specifier:)
												 get:@selector(readAccountValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
			[spec setProperty:@"saveSignedApp" forKey:@"key"];
			[spec setProperty:@NO forKey:@"default"];
		[specifiers addObject:spec];
		
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Show User Applications"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Enable" forKey:@"label"];
		[spec setProperty:@"By default Cydia Extender show only app thats has signed by account, it will enable all User apps to show in installed section." forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
						  target:self
												 set:@selector(setAccountValue:specifier:)
												 get:@selector(readAccountValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
			[spec setProperty:@"showUserApp" forKey:@"key"];
			[spec setProperty:@NO forKey:@"default"];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Background Translucent"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Background Translucent" forKey:@"label"];
		[spec setProperty:@"A nice Background in Ext3nder." forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
						  target:self
												 set:@selector(setAccountValue:specifier:)
												 get:@selector(readAccountValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
			[spec setProperty:@"BackgroundTranslucent" forKey:@"key"];
			[spec setProperty:@NO forKey:@"default"];
		[specifiers addObject:spec];
	
		spec = [PSSpecifier preferenceSpecifierNamed:@"Fast Zip Compression"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Fast Zip Compression" forKey:@"label"];
		[spec setProperty:@"Will Save Time & Battery Life When Building IPA Files." forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
						  target:self
												 set:@selector(setAccountValue:specifier:)
												 get:@selector(readAccountValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
			[spec setProperty:@"fastZipCompression" forKey:@"key"];
			[spec setProperty:@YES forKey:@"default"];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Ext3nder Notifications"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Ext3nder Notifications" forKey:@"label"];
		[spec setProperty:@"Hide/Show Type of Notification." forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Alert's"
						  target:self
												 set:@selector(setAccountValue:specifier:)
												 get:@selector(readAccountValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
			[spec setProperty:@"notificationAlerts" forKey:@"key"];
			[spec setProperty:@YES forKey:@"default"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Error's"
						  target:self
												 set:@selector(setAccountValue:specifier:)
												 get:@selector(readAccountValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
			[spec setProperty:@"notificationErrors" forKey:@"key"];
			[spec setProperty:@YES forKey:@"default"];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier emptyGroupSpecifier];
	[specifiers addObject:spec];
	
	
		spec = [PSSpecifier preferenceSpecifierNamed:@"Reset Preferences"
					      target:self
						 set:NULL
						 get:NULL
					      detail:Nil
						cell:PSButtonCell
						edit:Nil];
		spec->action = @selector(resetPrefs);
		[spec setProperty:NSClassFromString(@"SSTintedCell") forKey:@"cellClass"];
		[specifiers addObject:spec];
		
	
	
	spec = [PSSpecifier preferenceSpecifierNamed:@"Current Device Info"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Current Device Info" forKey:@"label"];
		[spec setProperty:@"Devide Info Used For Sign Apps." forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Name"
					      target:self
						 set:@selector(setAccountValue:specifier:)
						 get:@selector(readAccountValue:)
					      detail:Nil
						cell:PSEditTextCell
						edit:Nil];
		[spec setProperty:@"deviceName" forKey:@"key"];
		[spec setProperty:@"Fail, Please Reinstall Ext3nder" forKey:@"default"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Udid"
					      target:self
						 set:@selector(setAccountValue:specifier:)
						 get:@selector(readAccountValue:)
					      detail:Nil
						cell:PSEditTextCell
						edit:Nil];
		[spec setProperty:@"deviceUdid" forKey:@"key"];
		[spec setProperty:@"Fail, Please Reinstall Ext3nder" forKey:@"default"];
		[specifiers addObject:spec];
		/*	spec = [PSSpecifier preferenceSpecifierNamed:@"Add Device"
					      target:self
						 set:NULL
						 get:NULL
					      detail:Nil
						cell:PSButtonCell
						edit:Nil];
		spec->action = @selector(addCurrentDevice);
		[spec setProperty:NSClassFromString(@"SSTintedCell") forKey:@"cellClass"];
		[specifiers addObject:spec];*/
		
		spec = [PSSpecifier emptyGroupSpecifier];
	[specifiers addObject:spec];
	
		spec = [PSSpecifier emptyGroupSpecifier];
	[spec setProperty:@"Extendlife © 2017 julioverne" forKey:@"footerText"];
	[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Version"
					      target:self
						 set:NULL
						 get:@selector(readAccountValue:)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[spec setProperty:@"VersionE" forKey:@"key"];
		[spec setProperty:kVersion() forKey:@"default"];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier emptyGroupSpecifier];
	[specifiers addObject:spec];
		
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}
- (void)promptListAppIDs
{
	NSArray* allMail = getAllMails();
	if([allMail count] == 0) {
		showBanner(@"Please, Setup Apple Account In Ex3nder", YES);
	} else if([allMail count] == 1) {
		[self.navigationController pushViewController:[[objc_getClass("ListAppIDsController") alloc] initWithEmail:allMail[0]] animated:YES];
	} else {
		UIAlertView *alert = [[UIAlertView alloc]
		initWithTitle:@"Ext3nder"
		message:@"Choose Account (from Library)"
		delegate:self
		cancelButtonTitle:@"Cancel"
		otherButtonTitles:nil];
		[alert setContext:@"AcListAppIDs"];
		for(NSString* emailNow in allMail) {
			[alert addButtonWithTitle:emailNow];
		}
		[alert show];
	}
}
- (void)notifyPrefsChanges
{
	notify_post("com.julioverne.extendlife/Settings");
	[self performSelector:@selector(refresh:) withObject:nil afterDelay:0.4f];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/appChanged" object:nil];
	});
}
- (id)readAccountLibraryValue:(PSSpecifier*)specifier
{
	return [specifier properties][@"default"];
}
- (void)setAccountLibraryValue:(id)value specifier:(PSSpecifier *)specifier
{
	UIAlertView *alert = [[UIAlertView alloc]
	initWithTitle:@"Ext3nder"
	message:[NSString stringWithFormat:@"Delete Account \"%@\" ?", value]
	delegate:self
	cancelButtonTitle:@"Cancel"
	otherButtonTitles:@"Delete", nil];
    [alert setContext:@"AcLibrary"];
	NSDictionary* accountLibrary = accountLibraryDic()?:[NSDictionary dictionary];
	NSArray* allMail = [accountLibrary allKeys];
	alert.tag = [allMail indexOfObject:value];
	[alert show];
	
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:[specifier identifier]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	notify_post("com.julioverne.extendlife/Settings");
	[self performSelector:@selector(refresh:) withObject:nil afterDelay:0.4f];
}
- (void)setAccountValue:(id)value specifier:(PSSpecifier *)specifier
{
	@autoreleasepool {
		if([[specifier identifier] isEqualToString:@"AutoSignEnabled"]) {
			if([getAllMails() count] == 0) {
				showBanner(@"Please, Setup Apple Account In Ex3nder", YES);
				return;
			}
			/*
			NSString* emailVal = [[NSUserDefaults standardUserDefaults] objectForKey:@"SaveMail"];
			NSString* passVal = [[NSUserDefaults standardUserDefaults] objectForKey:@"SavePass"];
			if([value boolValue]&&(emailVal==nil||passVal==nil||(emailVal&&emailVal.length<1)||(passVal&&passVal.length<1))) {
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title message:@"This Option Requires \"Save Login Apple\" Email & Password Both Set." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
				[alert show];
				[self performSelector:@selector(refresh:) withObject:nil afterDelay:0.4f];
				return;
			}
			*/
		}
		[self.view endEditing:YES];
		if(value) {
			if([value isKindOfClass:[NSString class]]) {
				value = [value stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
			}			
			[[NSUserDefaults standardUserDefaults] setObject:value forKey:[specifier identifier]];
			[[NSUserDefaults standardUserDefaults] synchronize];
			notify_post("com.julioverne.extendlife/Settings");
			[self performSelector:@selector(refresh:) withObject:nil afterDelay:0.4f];
			if([[specifier identifier] isEqualToString:@"showUserApp"] || [[specifier identifier] isEqualToString:@"DaysLeftResign"]) {
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/appChanged" object:nil];
				});
			}
		}
	}
}
- (id)readAccountValue:(PSSpecifier*)specifier
{
	return [[NSUserDefaults standardUserDefaults] objectForKey:[specifier identifier]]?:[specifier properties][@"default"];
}
- (void)refresh:(UIRefreshControl *)refresh
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self reloadSpecifiers];
		if(refresh) {
			[refresh endRefreshing];
		}
	});
}
- (void)showErrorFormat
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title message:@"TeamID has wrong format.\n\nFormat accept:\nABCDEF1234" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}
- (void)showSucess:(NSString*)teamid
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title message:[NSString stringWithFormat:@"Success, Please Reopen Cydia Extender to Apply Changes.\n\nTeamID: %@", teamid] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}

- (void)setCurrentTeamIDValue:(id)value specifier:(PSSpecifier *)specifier
{
	@autoreleasepool {
		[self.view endEditing:YES];
		if(value&&[value length]==10) {
			value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			value = [value uppercaseString];
			if(teamID&&[value isEqualToString:teamID]) {
				[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"myTeamID"];
			} else {
				[[NSUserDefaults standardUserDefaults] setObject:value forKey:@"myTeamID"];
			}			
			[[NSUserDefaults standardUserDefaults] synchronize];
			notify_post("com.julioverne.extendlife/Settings");
			[self performSelector:@selector(refresh:) withObject:nil afterDelay:0.4f];
			[self showSucess:value];
		} else {
			[self showErrorFormat];
		}
	}
}
- (NSDictionary*)myAcInfoteamID:(NSDictionary*)account
{
	BOOL fetchTeamID = [account[@"fetchTeamID"]?:@NO boolValue];
	NSString* email = account[@"email"];
	NSString* password = account[@"password"];
	NSString* teamID = nil;
	NSString* myacinfo = nil;
	NSString* appIdKey = @"ba2ec180e6ca6e6c6a542255453b24d6e6e5b2be0cc48bc1b0d8ad64cfe0228f";
	NSString* clientId = @"XABBG36SBA";
	
	NSString* errorInfo = [NSString string];
	
	NSMutableArray* allTeamForMail = [NSMutableArray array];
	
	NSString* storedTeamForMail = getTeamForEmail(email);
	
	/*if(NSDictionary* cachedCredentialTmp = credentialForMail(email)) {
		return cachedCredentialTmp;
	}*/
	
	NSString *post = [NSString stringWithFormat:@"appIdKey=%@&appleId=%@&format=plist&password=%@&protocolVersion=A1234&userLocale=%@", appIdKey, urlEncodeUsingEncoding(email), urlEncodeUsingEncoding(password), currentLocaleId()];
	
	NSMutableURLRequest *postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://idmsa.apple.com/IDMSWebAuth/clientDAW.cgi"] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0f];
	[postRequest setHTTPMethod:@"POST"];
	[postRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[postRequest setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
	[postRequest setValue:@"en-us" forHTTPHeaderField:@"Accept-Langage"];
	NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	[postRequest setValue:[NSString stringWithFormat:@"%d", (int)[postData length]] forHTTPHeaderField:@"Content-Length"];
	[postRequest setHTTPBody:postData];
	NSHTTPURLResponse *response = nil;
	NSError *error = nil;
	NSData *responseData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
	if(error == nil && responseData != nil) {
		NSString *error;
		NSPropertyListFormat format;
		if(NSDictionary* plist = (NSDictionary*)[NSPropertyListSerialization propertyListFromData:responseData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error]) {
			NSString* errorInfoTx = plist[@"userString"]?:plist[@"resultString"];
			if(errorInfoTx) {
				errorInfo = [errorInfo stringByAppendingFormat:@"%@", errorInfoTx];
			}
			if(NSString* myacinfoValue = plist[@"myacinfo"]) {
				myacinfo = [myacinfoValue copy];
			}
		}
	}
	
	if(myacinfo != nil && fetchTeamID) {
	error = nil;
	NSMutableDictionary* mutPost = [[NSMutableDictionary alloc] init];
	mutPost[@"clientId"] = clientId;
	mutPost[@"myacinfo"] = myacinfo;
	mutPost[@"protocolVersion"] = @"QH65B2";
	mutPost[@"requestId"] = [[NSUUID UUID] UUIDString];
	mutPost[@"userLocale"] = @[currentLocaleId()];
	
	postData = [[NSPropertyListSerialization dataFromPropertyList:mutPost format:NSPropertyListXMLFormat_v1_0 errorDescription:nil] copy];
	
	postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/listTeams.action?clientId=XABBG36SBA"] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0f];
	[postRequest setHTTPMethod:@"POST"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"];
	[postRequest setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
	[postRequest setValue:@"en-us" forHTTPHeaderField:@"Accept-Langage"];
	[postRequest setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
	[postRequest setValue:[@"myacinfo=" stringByAppendingString:myacinfo] forHTTPHeaderField:@"Cookie"];
	[postRequest setValue:[NSString stringWithFormat:@"%d", (int)[postData length]] forHTTPHeaderField:@"Content-Length"];
	[postRequest setHTTPBody:postData];
	response = nil;
	error = nil;
	responseData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
	responseData = [[[NSData alloc] initWithBytes:responseData.bytes length:responseData.length] gunzippedData];
	if(error == nil && responseData != nil) {
		NSPropertyListFormat format;
		if(NSDictionary* plist = (NSDictionary*)[NSPropertyListSerialization propertyListFromData:responseData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil]) {
			NSString* errorInfoTx = plist[@"userString"]?:plist[@"resultString"];
			if(errorInfoTx) {
				errorInfo = [errorInfo stringByAppendingFormat:@"%@", errorInfoTx];
			}
			if(NSArray* teams = plist[@"teams"]) {
				for(NSDictionary* team in teams) {
					if(NSString* teamId = team[@"teamId"]) {
						[allTeamForMail addObject:teamId];
						if(storedTeamForMail && [teamId isEqualToString:storedTeamForMail]) {
							teamID = [teamId copy];
						}
					}
				}
				if(!teamID) {
					for(NSDictionary* team in teams) {
						if(NSString* teamId = team[@"teamId"]) {
							teamID = [teamId copy];
							break;
						}
					}
				}
			}
		}
	}
	}
	
	if(!teamID) {
		teamID = storedTeamForMail;
	}
	
	if(teamID && myacinfo) {
		//saveCredentialForMail(email, @{@"teamId":teamID, @"myacinfo": myacinfo});
		return [@{@"teamId":teamID, @"myacinfo": myacinfo, @"allTeams":allTeamForMail,} copy];
	}
	
	showBanner([NSString stringWithFormat:@"Error Get Account Info.%@", [errorInfo length]>0?[NSString stringWithFormat:@"\n%@", errorInfo]:@""], YES);
	return @{};
}
- (void)storeAccountWithEmail:(NSString*)email password:(NSString*)password team:(NSString*)team
{
	dispatch_async(dispatch_get_main_queue(), ^{
		saveAppleAccountInfo(email, password, team);
		if(YES) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			[self addDeviceAccount:email password:password];
			sleep(1/2);
			[self revokeAllKnowsAccounts];
		});
		}
	});	
}
- (void)saveAccount
{
	NSString* emailS = [[NSUserDefaults standardUserDefaults] objectForKey:@"SaveMail"];
	NSString* passwordS = [[NSUserDefaults standardUserDefaults] objectForKey:@"SavePass"];
	if((!emailS||!passwordS)||(emailS.length < 4 || passwordS.length < 4)) {
		showBanner(@"Empty Account Detail.", YES);
		return;
	}
	NSDictionary* accInfo = [self myAcInfoteamID:@{@"email":emailS,@"password":passwordS,@"fetchTeamID":@YES,}];
	NSArray* allTeams = accInfo[@"allTeams"]?:@[];
	if([allTeams count] == 0) {
		return;
	} else if([allTeams count] == 1 || isInBackgound) {
		[self storeAccountWithEmail:emailS password:passwordS team:allTeams[0]];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertView *alert = [[UIAlertView alloc]
		initWithTitle:@"Choose TeamID"
		message:emailS
		delegate:self
		cancelButtonTitle:@"Cancel"
		otherButtonTitles:nil];
		[alert setContext:[NSString stringWithFormat:@"AcSetTeamID%@", passwordS]];
		for(NSString* teamNow in allTeams) {
			[alert addButtonWithTitle:teamNow];
		}
		[alert show];
		});
	}
}
- (void)saveAccount_bt
{
	if(self.view) {
		[self.view endEditing:YES];
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		[self saveAccount];
	});
}
- (void)saveTeamID:(NSString*)email password:(NSString*)password
{
	if((!email||!password)||(email.length < 4 || password.length < 4)) {
		return;
	}
	
	if(!isNetworkReachable()) {
		showBanner([[NSBundle mainBundle] localizedStringForKey:@"NETWORK_ERROR" value:@"Network Error" table:nil], YES);
		return;
	}
	
	NSString* teamID = [self myAcInfoteamID:@{@"email":email,@"password":password,@"fetchTeamID":@YES,}][@"teamId"];
	if(teamID!=nil) {
		[self setCurrentTeamIDValue:teamID specifier:nil];
	}
}
- (BOOL)_revokeAccount:(NSString*)email password:(NSString*)password
{
	NSDictionary* teamInfo = [[self myAcInfoteamID:@{@"email":email,@"password":password,}] copy];
	NSString* teamID = teamInfo[@"teamId"];
	NSString* myacinfo = teamInfo[@"myacinfo"];
	if(teamID==nil || myacinfo==nil) {
		return NO;
	}
	
	NSString* clientId = @"XABBG36SBA";
	
	NSString* errorInfo = [NSString string];
	
	NSError* error = nil;
	NSMutableDictionary* mutPost = [[NSMutableDictionary alloc] init];
	mutPost[@"clientId"] = clientId;
	mutPost[@"myacinfo"] = myacinfo;
	mutPost[@"protocolVersion"] = @"QH65B2";
	mutPost[@"requestId"] = [[NSUUID UUID] UUIDString];
	mutPost[@"userLocale"] = @[currentLocaleId()];
	mutPost[@"DTDK_Platform"] = @"ios";
	mutPost[@"teamId"] = teamID;
	
	NSData* postData = [[NSPropertyListSerialization dataFromPropertyList:mutPost format:NSPropertyListXMLFormat_v1_0 errorDescription:nil] copy];
	
	NSMutableURLRequest* postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/ios/listAllDevelopmentCerts.action?clientId=XABBG36SBA"] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0f];
	[postRequest setHTTPMethod:@"POST"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"];
	[postRequest setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
	[postRequest setValue:@"en-us" forHTTPHeaderField:@"Accept-Langage"];
	[postRequest setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
	[postRequest setValue:[@"myacinfo=" stringByAppendingString:myacinfo] forHTTPHeaderField:@"Cookie"];
	[postRequest setValue:[NSString stringWithFormat:@"%d", (int)[postData length]] forHTTPHeaderField:@"Content-Length"];
	[postRequest setHTTPBody:postData];
	NSHTTPURLResponse* response = nil;
	error = nil;
	NSData* responseData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
	responseData = [[[NSData alloc] initWithBytes:responseData.bytes length:responseData.length] gunzippedData];
	NSMutableArray* allCertificatesSerial = [[NSMutableArray alloc] init];
	if(error == nil && responseData != nil) {
		NSPropertyListFormat format;
		if(NSDictionary* plist = (NSDictionary*)[NSPropertyListSerialization propertyListFromData:responseData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil]) {
			NSString* errorInfoTx = plist[@"userString"]?:plist[@"resultString"];
			if(errorInfoTx) {
				errorInfo = [errorInfo stringByAppendingFormat:@"%@", errorInfoTx];
			}
			if(NSArray* certificates = plist[@"certificates"]) {
				for(NSDictionary* certificate in certificates) {
					if(NSString* serialNumber = certificate[@"serialNumber"]) {
						[allCertificatesSerial addObject:serialNumber];
					}
				}
			}
		}
	}
	
	int countRevoke = 0;
	for(NSString* serialNumber in allCertificatesSerial) {
		error = nil;
		mutPost = [[NSMutableDictionary alloc] init];
		mutPost[@"clientId"] = clientId;
		mutPost[@"myacinfo"] = myacinfo;
		mutPost[@"protocolVersion"] = @"QH65B2";
		mutPost[@"requestId"] = [[NSUUID UUID] UUIDString];
		mutPost[@"userLocale"] = @[currentLocaleId()];
		mutPost[@"DTDK_Platform"] = @"ios";
		mutPost[@"teamId"] = teamID;
		mutPost[@"serialNumber"] = serialNumber;
		postData = [[NSPropertyListSerialization dataFromPropertyList:mutPost format:NSPropertyListXMLFormat_v1_0 errorDescription:nil] copy];
		
		postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/ios/revokeDevelopmentCert.action?clientId=XABBG36SBA"]
					    cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0f];
		[postRequest setHTTPMethod:@"POST"];
		[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"];
		[postRequest setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
		[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
		[postRequest setValue:@"en-us" forHTTPHeaderField:@"Accept-Langage"];
		[postRequest setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
		[postRequest setValue:[@"myacinfo=" stringByAppendingString:myacinfo] forHTTPHeaderField:@"Cookie"];
		[postRequest setValue:[NSString stringWithFormat:@"%d", (int)[postData length]] forHTTPHeaderField:@"Content-Length"];
		[postRequest setHTTPBody:postData];
		response = nil;
		error = nil;
		responseData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
		responseData = [[[NSData alloc] initWithBytes:responseData.bytes length:responseData.length] gunzippedData];
		if(error == nil && responseData != nil) {
			NSPropertyListFormat format;
			if(NSDictionary* plist = (NSDictionary*)[NSPropertyListSerialization propertyListFromData:responseData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil]) {
				NSString* errorInfoTx = plist[@"userString"]?:plist[@"resultString"];
				if(errorInfoTx) {
					errorInfo = [errorInfo stringByAppendingFormat:@"%@", errorInfoTx];
				}
				if(id resultCode = plist[@"resultCode"]) {
					if([resultCode intValue]==0) {
						countRevoke++;
					}
				}
			}
		}
	}
	
	system("rm -rf //var/mobile/Documents/Ext3nder/Signed/");
	recentInstalledBundleIDAfterRevoke = [[NSMutableArray alloc] init];
	
	if(showRevokeNotification) {
		showBanner([NSString stringWithFormat:@"Revoked %@ Certificates \"%@\".%@", @(countRevoke), email, [errorInfo length]>0?[NSString stringWithFormat:@"\n%@", errorInfo]:@""], NO);
	}
	return YES;
}
- (void)revokeAccount:(NSString*)email password:(NSString*)password
{
	if((!email||!password)||(email.length < 4 || password.length < 4)) {
		return;
	}
	
	if(!isNetworkReachable()) {
		showBanner([[NSBundle mainBundle] localizedStringForKey:@"NETWORK_ERROR" value:@"Network Error" table:nil], YES);
		return;
	}
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		BOOL suss = [self _revokeAccount:email password:password];
		if(suss) {
			[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"revokedDate"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			notify_post("com.julioverne.extendlife/Settings");
		}
	});
}
- (void)revokeAllKnowsAccounts
{
	if([getAllMails() count] == 0) {
		showBanner(@"Please, Setup Apple Account In Ex3nder", YES);
		return;
	}
	if(!isNetworkReachable()) {
		showBanner([[NSBundle mainBundle] localizedStringForKey:@"NETWORK_ERROR" value:@"Network Error" table:nil], YES);
		return;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		BOOL suss;
		for(NSString* emailNowSt in getAllMails()) {
			suss = [self _revokeAccount:emailNowSt password:getPassForEmail(emailNowSt)];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"revokedDate"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		notify_post("com.julioverne.extendlife/Settings");
		
		goNextPackageQueued();			
	});
}
- (void)addDeviceAccount:(NSString*)email password:(NSString*)password
{
	if((!email||!password)||(email.length < 4 || password.length < 4)) {
		return;
	}
	
	if(!isNetworkReachable()) {
		showBanner([[NSBundle mainBundle] localizedStringForKey:@"NETWORK_ERROR" value:@"Network Error" table:nil], YES);
		return;
	}
	
	if(!deviceName||!deviceUdid||(deviceName&&deviceName.length==0)||(deviceUdid&&deviceUdid.length!=40)) {
		showBanner(@"Error Get Device Info.", YES);
		return;
	}
	
	NSDictionary* teamInfo = [[self myAcInfoteamID:@{@"email":email,@"password":password,}] copy];
	NSString* teamID = teamInfo[@"teamId"];
	NSString* myacinfo = teamInfo[@"myacinfo"];
	if(teamID==nil) {
		return;
	}
	NSString* errorInfo = [NSString string];
	NSString* clientId = @"XABBG36SBA";
	
	BOOL deviceAlreadyListed = NO;
	NSError* error = nil;
	NSMutableDictionary* mutPost = [[NSMutableDictionary alloc] init];
	mutPost[@"clientId"] = clientId;
	mutPost[@"myacinfo"] = myacinfo;
	mutPost[@"protocolVersion"] = @"QH65B2";
	mutPost[@"requestId"] = [[NSUUID UUID] UUIDString];
	mutPost[@"userLocale"] = @[currentLocaleId()];
	mutPost[@"DTDK_Platform"] = @"ios";
	mutPost[@"teamId"] = teamID;
	
	NSData* postData = [[NSPropertyListSerialization dataFromPropertyList:mutPost format:NSPropertyListXMLFormat_v1_0 errorDescription:nil] copy];
	
	NSMutableURLRequest* postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/ios/listDevices.action?clientId=XABBG36SBA"]
					    cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0f];
	[postRequest setHTTPMethod:@"POST"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"];
	[postRequest setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
	[postRequest setValue:@"en-us" forHTTPHeaderField:@"Accept-Langage"];
	[postRequest setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
	[postRequest setValue:[@"myacinfo=" stringByAppendingString:myacinfo] forHTTPHeaderField:@"Cookie"];
	[postRequest setValue:[NSString stringWithFormat:@"%d", (int)[postData length]] forHTTPHeaderField:@"Content-Length"];
	[postRequest setHTTPBody:postData];
	NSHTTPURLResponse* response = nil;
	error = nil;
	NSData* responseData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
	responseData = [[[NSData alloc] initWithBytes:responseData.bytes length:responseData.length] gunzippedData];
	NSMutableArray* allCertificatesSerial = [[NSMutableArray alloc] init];
	if(error == nil && responseData != nil) {
		NSPropertyListFormat format;
		if(NSDictionary* plist = (NSDictionary*)[NSPropertyListSerialization propertyListFromData:responseData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil]) {
			NSString* errorInfoTx = plist[@"userString"]?:plist[@"resultString"];
			if(errorInfoTx) {
				errorInfo = [errorInfo stringByAppendingFormat:@"%@", errorInfoTx];
			}
			if(NSArray* devices = plist[@"devices"]) {
				for(NSDictionary* device in devices) {
					if(NSString* deviceNumberValue = device[@"deviceNumber"]) {
						if(deviceUdid&&[deviceNumberValue isEqualToString:deviceUdid]) {
							deviceAlreadyListed = YES;
							showBanner([NSString stringWithFormat:@"Device Already in your Account \"%@\".\n\nname: %@\ndeviceId: %@\nmodel: %@\nstatus: %@\ndeviceNumber: %@",
							email, device[@"name"], device[@"deviceId"], device[@"model"], device[@"status"], device[@"deviceNumber"]], NO);
							break;
						}
					}
				}
			}
		}
	}
	
	if(deviceAlreadyListed) {
		return;
	}
	
	error = nil;
	mutPost = [[NSMutableDictionary alloc] init];
	mutPost[@"clientId"] = clientId;
	mutPost[@"myacinfo"] = myacinfo;
	mutPost[@"protocolVersion"] = @"QH65B2";
	mutPost[@"requestId"] = [[NSUUID UUID] UUIDString];
	mutPost[@"userLocale"] = @[currentLocaleId()];
	mutPost[@"DTDK_Platform"] = @"ios";
	mutPost[@"teamId"] = teamID;
	mutPost[@"deviceNumber"] = deviceUdid;
	mutPost[@"name"] = deviceName;
	
	postData = [[NSPropertyListSerialization dataFromPropertyList:mutPost format:NSPropertyListXMLFormat_v1_0 errorDescription:nil] copy];
	
	postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/ios/addDevice.action?clientId=XABBG36SBA"]
					    cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0f];
	[postRequest setHTTPMethod:@"POST"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"];
	[postRequest setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
	[postRequest setValue:@"en-us" forHTTPHeaderField:@"Accept-Langage"];
	[postRequest setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
	[postRequest setValue:[@"myacinfo=" stringByAppendingString:myacinfo] forHTTPHeaderField:@"Cookie"];
	[postRequest setValue:[NSString stringWithFormat:@"%d", (int)[postData length]] forHTTPHeaderField:@"Content-Length"];
	[postRequest setHTTPBody:postData];
	response = nil;
	error = nil;
	responseData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
	responseData = [[[NSData alloc] initWithBytes:responseData.bytes length:responseData.length] gunzippedData];
	allCertificatesSerial = [[NSMutableArray alloc] init];
	if(error == nil && responseData != nil) {
		NSPropertyListFormat format;
		if(NSDictionary* plist = (NSDictionary*)[NSPropertyListSerialization propertyListFromData:responseData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil]) {
			NSString* errorInfoTx = plist[@"userString"]?:plist[@"resultString"];
			if(errorInfoTx) {
				errorInfo = [errorInfo stringByAppendingFormat:@"%@", errorInfoTx];
			}
			if(NSDictionary* device = plist[@"device"]) {
				if(NSString* deviceNumberValue = device[@"deviceNumber"]) {
					if(deviceUdid&&[deviceNumberValue isEqualToString:deviceUdid]) {
						showBanner([NSString stringWithFormat:@"Device Added Successfully In Account \"%@\".\n\nname: %@\ndeviceId: %@\nmodel: %@\nstatus: %@\ndeviceNumber: %@", email, device[@"name"], device[@"deviceId"], device[@"model"], device[@"status"], device[@"deviceNumber"]], NO);
						return;
					}
				}
			}
		}
	}
	
	showBanner([NSString stringWithFormat:@"Error Adding Device To Account \"%@\".%@", email, [errorInfo length]>0?[NSString stringWithFormat:@"\n%@", errorInfo]:@""], YES);
}

- (void)requestTeamID:(BOOL)revoke
{
    UIAlertView *alert = [[UIAlertView alloc]
	initWithTitle:@"Apple Developer"
	message:@"Your password is only sent to Apple."
	delegate:self
	cancelButtonTitle:@"Cancel"
	otherButtonTitles:revoke?@"Revoke":@"Login", nil
	];
    [alert setContext:@"TeamID"];
    [alert setNumberOfRows:2];
	[alert addTextFieldWithValue:@"" label:@"Apple ID"];
    [alert addTextFieldWithValue:@"" label:@"Password"];
    UITextField *traitsF = [[alert textFieldAtIndex:1] textInputTraits];
    [traitsF setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [traitsF setAutocorrectionType:UITextAutocorrectionTypeNo];
    [traitsF setKeyboardType:UIKeyboardTypeURL];
    [traitsF setReturnKeyType:UIReturnKeyNext];
    [alert show];
}
- (void)addCurrentDevice
{
	if([getAllMails() count] == 0) {
		showBanner(@"Please, Setup Apple Account In Ex3nder", YES);
		return;
	}
	UIAlertView *alert = [[UIAlertView alloc]
	initWithTitle:@"Apple Developer"
	message:@"Your password is only sent to Apple."
	delegate:self
	cancelButtonTitle:@"Cancel"
	otherButtonTitles:@"Add Device", nil
	];
    [alert setContext:@"TeamID"];
    [alert setNumberOfRows:2];
	[alert addTextFieldWithValue:@"" label:@"Apple ID"];
    [alert addTextFieldWithValue:@"" label:@"Password"];
    UITextField *traitsF = [[alert textFieldAtIndex:1] textInputTraits];
    [traitsF setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [traitsF setAutocorrectionType:UITextAutocorrectionTypeNo];
    [traitsF setKeyboardType:UIKeyboardTypeURL];
    [traitsF setReturnKeyType:UIReturnKeyNext];
    [alert show];
}
- (void)revokeCert
{
	if([getAllMails() count] == 0) {
		showBanner(@"Please, Setup Apple Account In Ex3nder", YES);
		return;
	}
	[self requestTeamID:YES];
}
- (void)getTeamID
{
	[self requestTeamID:NO];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(long long)button
{
	@try {
		NSString *context([alert context]);
		if (button == [alert cancelButtonIndex]) {
			return;
		}
		if ([context isEqualToString:@"TeamID"]) {
			NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
			NSString *email = [[alert textFieldAtIndex:0] text];
			NSString *pass = [[alert textFieldAtIndex:1] text];
			if([buttonTitle isEqualToString:@"Login"]) {
				[self saveTeamID:email password:pass];
			} else if([buttonTitle isEqualToString:@"Revoke"]) {
				[self revokeAccount:email password:pass];
			} else if([buttonTitle isEqualToString:@"Add Device"]) {
				[self addDeviceAccount:email password:pass];
			}
		}
		if ([context isEqualToString:@"AcLibrary"]) {
			NSMutableDictionary* accountLibrary = [accountLibraryDic()?:[NSDictionary dictionary] mutableCopy];
			[accountLibrary removeObjectForKey:[accountLibrary allKeys][alert.tag]];
			[[NSUserDefaults standardUserDefaults] setObject:accountLibrary forKey:@"accountLibrary"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			notify_post("com.julioverne.extendlife/Settings");
			[[SettingsExtendlife shared] performSelector:@selector(refresh:) withObject:nil afterDelay:0.4f];
			[self.navigationController popToRootViewControllerAnimated:YES];
		}
		if ([context isEqualToString:@"AcListAppIDs"]) {
			NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
			[self.navigationController pushViewController:[[objc_getClass("ListAppIDsController") alloc] initWithEmail:buttonTitle] animated:YES];
		}
		if ([context hasPrefix:@"AcSetTeamID"]) {
			NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
			[self storeAccountWithEmail:alert.message password:[context substringFromIndex:11] team:buttonTitle];
		}		
		
	} @catch (NSException * e) {
		//
	}
	[alert dismissWithClickedButtonIndex:-1 animated:YES];
}
- (id)readValue:(PSSpecifier*)specifier
{
	return nil;
}
- (void)_returnKeyPressed:(id)arg1
{
	[super _returnKeyPressed:arg1];
	[self.view endEditing:YES];
}

- (void) loadView
{
	[super loadView];
	self.title = @"Extendlife";	
	static __strong UIRefreshControl *refreshControl;
	if(!refreshControl) {
		refreshControl = [[UIRefreshControl alloc] init];
		[refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
		refreshControl.tag = 8654;
	}	
	if(UITableView* tableV = (UITableView *)object_getIvar(self, class_getInstanceVariable([self class], "_table"))) {
		if(UIView* rem = [tableV viewWithTag:8654]) {
			[rem removeFromSuperview];
		}
		[tableV addSubview:refreshControl];
		
		if(BackgroundTranslucent) {
			//tableV.alpha = 0.65;
			tableV.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3f];
		}
		
	}
	if(BackgroundTranslucent) {
		//self.view.alpha = 0.65;
		self.view.backgroundColor = [UIColor clearColor];
	}
}
- (void)resetPrefs
{
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
	[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
	[self notifyPrefsChanges];
	queueAlertBar(@"Preferences Reseted.");
}
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self refresh:nil];
}
/*
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return (indexPath.section == 0);
}
- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 0);
}
- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    return (action == @selector(copy:));
}
- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:)) {
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
	[pasteBoard setString:cell.textLabel.text];
    }
}
*/			
@end


@implementation ListAppIDsController
@synthesize data, email;
- (id)initWithEmail:(NSString*)emailSt
{
	self = [super init];
	email = emailSt;
	data = @{};
	return self;
}
- (void)removeAppID:(NSString*)appId
{
	if(!appId) {
		return;
	}
	
	__block UIProgressHUD* hud = [[UIProgressHUD alloc] init];
	[hud setText:@"Deleting..."];
	[hud showInView:self.view];
	[self.view setUserInteractionEnabled:NO];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			
			
	SettingsExtendlife* SettSH = [SettingsExtendlife shared];
	NSDictionary* teamInfo = [[SettSH myAcInfoteamID:@{@"email":email,@"password":getPassForEmail(email),}] copy];
	NSString* teamID = teamInfo[@"teamId"];
	NSString* myacinfo = teamInfo[@"myacinfo"];
	if(teamID==nil) {
		return;
	}
	NSString* errorInfo = [NSString string];
	NSString* clientId = @"XABBG36SBA";
	
	NSError* error = nil;
	NSMutableDictionary* mutPost = [[NSMutableDictionary alloc] init];
	mutPost[@"clientId"] = clientId;
	mutPost[@"myacinfo"] = myacinfo;
	mutPost[@"protocolVersion"] = @"QH65B2";
	mutPost[@"requestId"] = [[NSUUID UUID] UUIDString];
	mutPost[@"userLocale"] = @[currentLocaleId()];
	mutPost[@"DTDK_Platform"] = @"ios";
	mutPost[@"teamId"] = teamID;
	mutPost[@"appIdId"] = appId;
	
	NSData* postData = [[NSPropertyListSerialization dataFromPropertyList:mutPost format:NSPropertyListXMLFormat_v1_0 errorDescription:nil] copy];
	
	NSMutableURLRequest* postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/ios/deleteAppId.action?clientId=XABBG36SBA"] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0f];
	[postRequest setHTTPMethod:@"POST"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"];
	[postRequest setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
	[postRequest setValue:@"en-us" forHTTPHeaderField:@"Accept-Langage"];
	[postRequest setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
	[postRequest setValue:[@"myacinfo=" stringByAppendingString:myacinfo] forHTTPHeaderField:@"Cookie"];
	[postRequest setValue:[NSString stringWithFormat:@"%d", (int)[postData length]] forHTTPHeaderField:@"Content-Length"];
	[postRequest setHTTPBody:postData];
	NSHTTPURLResponse* response = nil;
	error = nil;
	NSData* responseData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
	responseData = [[[NSData alloc] initWithBytes:responseData.bytes length:responseData.length] gunzippedData];
	if(error == nil && responseData != nil) {
		NSPropertyListFormat format;
		if(NSDictionary* plist = (NSDictionary*)[NSPropertyListSerialization propertyListFromData:responseData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil]) {
			NSString* errorInfoTx = plist[@"userString"]?:plist[@"resultString"];
			if(errorInfoTx) {
				errorInfo = [errorInfo stringByAppendingFormat:@"%@", errorInfoTx];
			}
		}
	}
	
	showBanner([NSString stringWithFormat:@"%@App ID \"%@\" from Account \"%@\".%@", [errorInfo length]>0?@"Error Delete ":@"Deleted ", data[appId][@"name"], email, [errorInfo length]>0?[NSString stringWithFormat:@"\n%@", errorInfo]:@""], [errorInfo length]>0?YES:NO);
	
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[hud hide];
		[self.view setUserInteractionEnabled:YES];
		[self Refresh];
	});
	
	});
}
- (void)Refresh
{
	if(!email) {
		return;
	}
	
	__block UIProgressHUD* hud = [[UIProgressHUD alloc] init];
	[hud setText:@"List Apps..."];
	[hud showInView:self.view];
	[self.view setUserInteractionEnabled:NO];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			
			
	SettingsExtendlife* SettSH = [SettingsExtendlife shared];
	NSDictionary* teamInfo = [[SettSH myAcInfoteamID:@{@"email":email,@"password":getPassForEmail(email),}] copy];
	NSString* teamID = teamInfo[@"teamId"];
	NSString* myacinfo = teamInfo[@"myacinfo"];
	if(teamID==nil) {
		return;
	}
	NSString* errorInfo = [NSString string];
	NSString* clientId = @"XABBG36SBA";
	
	NSError* error = nil;
	NSMutableDictionary* mutPost = [[NSMutableDictionary alloc] init];
	mutPost[@"clientId"] = clientId;
	mutPost[@"myacinfo"] = myacinfo;
	mutPost[@"protocolVersion"] = @"QH65B2";
	mutPost[@"requestId"] = [[NSUUID UUID] UUIDString];
	mutPost[@"userLocale"] = @[currentLocaleId()];
	mutPost[@"DTDK_Platform"] = @"ios";
	mutPost[@"teamId"] = teamID;
	
	NSData* postData = [[NSPropertyListSerialization dataFromPropertyList:mutPost format:NSPropertyListXMLFormat_v1_0 errorDescription:nil] copy];
	
	NSMutableURLRequest* postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/ios/listAppIds.action?clientId=XABBG36SBA"] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0f];
	[postRequest setHTTPMethod:@"POST"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"];
	[postRequest setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
	[postRequest setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
	[postRequest setValue:@"en-us" forHTTPHeaderField:@"Accept-Langage"];
	[postRequest setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
	[postRequest setValue:[@"myacinfo=" stringByAppendingString:myacinfo] forHTTPHeaderField:@"Cookie"];
	[postRequest setValue:[NSString stringWithFormat:@"%d", (int)[postData length]] forHTTPHeaderField:@"Content-Length"];
	[postRequest setHTTPBody:postData];
	NSHTTPURLResponse* response = nil;
	error = nil;
	NSData* responseData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
	responseData = [[[NSData alloc] initWithBytes:responseData.bytes length:responseData.length] gunzippedData];
	if(error == nil && responseData != nil) {
		NSPropertyListFormat format;
		if(NSDictionary* plist = (NSDictionary*)[NSPropertyListSerialization propertyListFromData:responseData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil]) {
			NSString* errorInfoTx = plist[@"userString"]?:plist[@"resultString"];
			if(errorInfoTx) {
				errorInfo = [errorInfo stringByAppendingFormat:@"%@", errorInfoTx];
			}
			NSMutableDictionary* dataMut = [NSMutableDictionary dictionary];
			for(NSDictionary* appIdNow in plist[@"appIds"]) {
				dataMut[appIdNow[@"appIdId"]] = @{
					@"name":appIdNow[@"name"]?:@"",
					@"identifier":appIdNow[@"identifier"]?:@"",
					@"prefix":appIdNow[@"prefix"]?:@"",
					@"appIdId":appIdNow[@"appIdId"]?:@"",
				};
			}
			data = [dataMut copy];
		}
	}
	
	if([errorInfo length] > 0) {
		showBanner([NSString stringWithFormat:@"Error List App ID \"%@\".\n%@", email, errorInfo], YES);
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[hud hide];
		[self.view setUserInteractionEnabled:YES];
		[self.tableView reloadData];
	});
	
	});
}
- (void)refreshView:(UIRefreshControl *)refresh
{
	[self Refresh];
	[refresh endRefreshing];
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
	[self Refresh];
}
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"%@", data[[data allKeys][indexPath.row]]] delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
	[popup setDestructiveButtonIndex:[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Delete" value:@"Delete" table:nil]]];
	[popup addButtonWithTitle:[[NSBundle mainBundle] localizedStringForKey:@"CANCEL" value:nil table:nil]];
	[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
	popup.tag = indexPath.row;
	[popup setContext:@"appIdDel"];
	if (isDeviceIPad) {
		[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
	} else {
		[popup showInView:self.view];
	}
	return nil;
}
- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	NSString* contextAlert = [alert context];
	NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
	
	if(contextAlert&&[contextAlert isEqualToString:@"appIdDel"]) {
		if (button == [alert cancelButtonIndex]) {
			
		} else if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Delete" value:@"Delete" table:nil]]) {
			[self removeAppID:[data allKeys][alert.tag]];
		}
	}
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[data allKeys] count];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [NSString stringWithFormat:@"%@ (%d)", email, (int)[[data allKeys] count]];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static __strong NSString *simpleTableIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
	if(cell== nil) {
	    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:simpleTableIdentifier];			
    }
	
	cell.textLabel.text =  nil;
	cell.detailTextLabel.text = nil;
	cell.textLabel.textColor = [UIColor darkTextColor];
	cell.detailTextLabel.textColor = [UIColor grayColor];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.imageView.image = nil;
	
	cell.textLabel.numberOfLines = 1;
	cell.detailTextLabel.numberOfLines = 1;
	
	cell.textLabel.font = [UIFont systemFontOfSize:12];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:10];
	
	NSDictionary* appIdData = data[[data allKeys][indexPath.row]];
	
	cell.textLabel.text = appIdData[@"name"];
	cell.detailTextLabel.text = appIdData[@"identifier"];
	
    return cell;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return	YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self removeAppID:[data allKeys][indexPath.row]];
}
@end
