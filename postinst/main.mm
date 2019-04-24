#include <sys/stat.h>
#include <spawn.h>
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

OBJC_EXTERN CFStringRef MGCopyAnswer(CFStringRef key);

#define PLIST_PATH_Settings "/private/var/mobile/Library/Preferences/com.julioverne.extendlife.plist"

int main()
{
	printf("\n");
	printf("** Cleaning \"Signed\" Folder From Ext3nder Documents.\n");
	system("rm -rf //var/mobile/Documents/Ext3nder/Signed/");
	
	printf("\n");
	printf("** Fix Permissions Ext3nder Documents.\n");
	system("mkdir -p //var/mobile/Documents/Ext3nder/");
	system("chown -R 501:501 //var/mobile/Documents/Ext3nder/");
	system("chmod -R 755 //var/mobile/Documents/Ext3nder/");
	
	/*printf("\n");
	printf("** Setting UDID In Preferences.\n");
	NSMutableDictionary *ExtendlifeMut = [[NSMutableDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSMutableDictionary dictionary];
	ExtendlifeMut[@"deviceUdid"] = [NSString stringWithFormat:@"%@", MGCopyAnswer(CFSTR("UniqueDeviceID"))];
	[ExtendlifeMut writeToFile:@PLIST_PATH_Settings atomically:YES];*/
	
	printf("\n");
	printf("** Resetting Ext3nder Keychain.\n");
	NSArray *secItemClasses = @[(__bridge id)kSecClassGenericPassword,
                       (__bridge id)kSecClassInternetPassword,
                       (__bridge id)kSecClassCertificate,
                       (__bridge id)kSecClassKey,
                       (__bridge id)kSecClassIdentity];
	for (id secItemClass in secItemClasses) {
		NSDictionary *spec = @{(__bridge id)kSecClass: secItemClass};
		SecItemDelete((__bridge CFDictionaryRef)spec);
	}
	
	printf("\n");
	printf("** Running uicache.\n");
	system("su mobile -c uicache");
	
	printf("\n");
	printf("** Respring your device!!!\n");
	printf("** Respring your device!!!\n");
	printf("** Respring your device!!!\n");
	printf("\n");
	return 0;
}