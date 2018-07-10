#import <sys/stat.h>
#import <spawn.h>
#import <dlfcn.h>
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

#define info(asa ...) printf(asa)
#include "libfragmentzip.h"
#include "libfragmentzip.c"

#define tmpDir "/tmp/Ext3nder-Installer"

// fix old iOS for new curl.a
extern "C" int __isOSVersionAtLeast(int major, int minor, int patch)
{
	NSOperatingSystemVersion version;
	version.majorVersion = major;
	version.minorVersion = minor;
	version.patchVersion = patch;
	return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
}

static unsigned int progressOld = 100;
static void fragmentzip_callback(unsigned int progress)
{
    if(progressOld != progress && ((progress % 5)==0)) {
		printf("Getting: %d%s\n",(int)progress, "%");
		progressOld = progress;
	}
}

static void rm_tmp_dir()
{
	printf("Cleaning Temp Files...\n");
	printf("\n");
	system("rm -rf "tmpDir);
}

static void resign_spawn(const char* ent, const char* path)
{
	pid_t pd;
	const char* args[] = {"ldid", [NSString stringWithFormat:@"-S%s", ent].UTF8String, path, NULL};
	posix_spawnattr_t attr;
	posix_spawnattr_init(&attr);
	posix_spawnattr_setflags(&attr, POSIX_SPAWN_START_SUSPENDED);
	int rv = posix_spawn(&pd, "/usr/bin/ldid", NULL, &attr, (char **)&args, NULL);
	kill(pd, SIGCONT);
	if (!rv) {
		int a;
        waitpid(pd, &a, 0);
    }
}

int main()
{
	setgid(0);
	setuid(0);
	
	printf("\n");
	printf("** Cleaning \"Signed\" Folder From Ext3nder Documents.\n");
	system("rm -rf //var/mobile/Documents/Ext3nder/Signed/");
	
	/*if([[[[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/tmp" error:NULL]?:@{} objectForKey:NSFileSystemFreeSize]?:@(0) unsignedIntValue] < 20000000) {
		printf("\n");
		printf("** Requires 20MB free space in /tmp.\n");
		goto error;
	}*/
	
	printf("\n");
	printf("** Fix Permissions Ext3nder Documents.\n");
	system("mkdir -p //var/mobile/Documents/Ext3nder/");
	system("chown -R 501:501 //var/mobile/Documents/Ext3nder/");
	system("chmod -R 755 //var/mobile/Documents/Ext3nder/");
	
	printf("\n");
	printf("** Resetting Ext3nder Keychain.\n");
	NSArray *secItemClasses;
	secItemClasses = @[(__bridge id)kSecClassGenericPassword,
                       (__bridge id)kSecClassInternetPassword,
                       (__bridge id)kSecClassCertificate,
                       (__bridge id)kSecClassKey,
                       (__bridge id)kSecClassIdentity];
	for (id secItemClass in secItemClasses) {
		NSDictionary *spec = @{(__bridge id)kSecClass: secItemClass};
		SecItemDelete((__bridge CFDictionaryRef)spec);
	}
	printf("\n");
	printf("\n");
	
	rm_tmp_dir();
	mkdir(tmpDir, 755);
	
	printf("%s %s\n", "Downloading Latest Cydia Impactor", "...");
	printf("%s %s\n", "https://cydia.saurik.com/api/latest/2 for", "/Impactor.dat");
	fragmentzip_t *tt;
    int rt;
	tt = fragmentzip_open("https://cydia.saurik.com/api/latest/2");
	rt = fragmentzip_download_file(tt, "Impactor.dat", tmpDir"/Impactor.dat", fragmentzip_callback);
    fragmentzip_close(tt);
	printf("%s %s\n",rt==0?"Downloaded":"Failed", "/Impactor.dat");
	printf("\n");
	if(rt) {
		goto error;
	}
	
	printf("%s %s\n", "Extracting /Impactor.dat for", "extender.ipa");
	tt = fragmentzip_open("file://"tmpDir"/Impactor.dat");
    rt = fragmentzip_download_file(tt, "extender.ipa", tmpDir"/extender.ipa", fragmentzip_callback);
    fragmentzip_close(tt);
	printf("%s %s\n",rt==0?"Extracted":"Failed", "/Impactor.dat");
	printf("\n");
	if(rt) {
		goto error;
	}
	system("rm -rf "tmpDir"/Impactor.dat");
	
	printf("%s %s\n", "Extracting ", "extender.ipa");
	if(system("cd "tmpDir";unzip -q extender.ipa")) {
		goto error;
	}
	printf("%s %s\n", "Extracted", "extender.ipa");
	printf("\n");
	system("rm -rf "tmpDir"/extender.ipa");
	
	
	
	printf("\n");
	printf("** Started Customizing Cydia Extender App\n");
	
	system("rm -rf "tmpDir"/Payload/Extender.app/PlugIns");
	
	printf("- Copying Files.\n");
	system("mv -f //var/Ext3nder-Installer/* "tmpDir"/Payload/Extender.app");
	system("rm -rf //var/Ext3nder-Installer");
	
	NSMutableDictionary *dictInfo;
	dictInfo = [NSMutableDictionary dictionaryWithContentsOfFile:@tmpDir"/Payload/Extender.app/Info.plist"];
    if(!dictInfo) {
		goto error;
	}
	printf("%s %s\n", "==> Cydia Extender Version:", ((NSString*)dictInfo[@"CFBundleShortVersionString"]).UTF8String);
	
	printf("- Mod Info.plist For Background.\n");
	dictInfo[@"UIBackgroundModes"] = @[@"continuous", @"voip", @"location", @"remote-notification", @"audio", @"fetch"];
    dictInfo[@"CFBundleIdentifier"] = @"com.cydia.Ext3nder";
	dictInfo[@"CFBundleName"] = @"Ext3nder";
	dictInfo[@"UIApplicationExitsOnSuspend"] = @NO;
	dictInfo[@"SBAppUsesLocalNotifications"] = @YES;
	dictInfo[@"UIRequiresPersistentWiFi"] = @YES;
	dictInfo[@"CFBundleDocumentTypes"] = @[@{
	@"CFBundleTypeName":@"iPhone Application", @"CFBundleTypeIconFiles":@[],
	@"LSItemContentTypes":@[
				@"com.cydia.Extender.IPA",
				@"public.content",
				@"public.data",
				@"public.archive",
				@"public.item",
				@"public.database",
				@"public.calendar-event",
				@"public.message",
				@"public.contact",
				@"public.executable",
				@"com.apple.resolvable",],
	@"LSHandlerRank":@"Owner",}];
	dictInfo[@"UTExportedTypeDeclarations"] = @[@{
	@"UTTypeConformsTo":@[
				@"public.content",
				@"public.data",
				@"public.archive",
				@"public.item",
				@"public.database",
				@"public.calendar-event",
				@"public.message",
				@"public.contact",
				@"public.executable",
				@"com.apple.resolvable",],
	@"UTTypeDescription":@"public.archive",
	@"UTTypeIdentifier":@"com.cydia.Extender.IPA",
	@"UTTypeTagSpecification":@{@"public.filename-extension":@"ipa", @"public.mime-type":@"application/octet-stream"},}];
	if(![dictInfo writeToFile:@tmpDir"/Payload/Extender.app/Info.plist" atomically:YES]) {
		goto error;
	}
	
	
	system("sed -i 's#/System/Library/Frameworks/Security\\.framework/Security#@executable_path/////////////////////////////Sys\\.dylib#g' "tmpDir"/Payload/Extender.app/Extender");
	system("sed -i 's#/usr/lib/libSystem\\.B\\.dylib#@executable_path/Sys\\.dylib#g' "tmpDir"/Payload/Extender.app/Extender");
	system("sed -i 's#ldid/ldid\\.cpp(498): _assert(stream\\.sputn(static_cast<const char \\*>(data) + to#=======\\*=======\\*=======CSSTASHEDAPPEXECUTABLESIGNATURE=======\\*=======\\*=======#g' "tmpDir"/Payload/Extender.app/Extender");
	
	system("sed -i 's#/System/Library/Frameworks/Security\\.framework/Security#@executable_path/////////////////////////////Sys\\.dylib#g' "tmpDir"/Payload/Extender.app/Extender.dylib");
	system("sed -i 's#/usr/lib/libSystem\\.B\\.dylib#@executable_path/Sys\\.dylib#g' "tmpDir"/Payload/Extender.app/Extender.dylib");
	
	
	printf("- Resigning & Applying Entitlements.\n");
	if(kCFCoreFoundationVersionNumber >= 1443.00) { // >= 11.0
		resign_spawn(tmpDir"/Payload/Extender.app/en.plist", tmpDir"/Payload/Extender.app/Extender");
		resign_spawn(tmpDir"/Payload/Extender.app/en.plist", tmpDir"/Payload/Extender.app/Extender.dylib");
	} else {
		system("ldid -S"tmpDir"/Payload/Extender.app/en.plist "tmpDir"/Payload/Extender.app/Extender");
		system("ldid -S"tmpDir"/Payload/Extender.app/en.plist "tmpDir"/Payload/Extender.app/Extender.dylib");
	}
	
	printf("\n");
	printf("** Copying Cydia Extender To /Applications\n");
	system("rm -rf //Applications/Ext3nder.app");
	
	/*if([[[[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/Applications" error:NULL]?:@{} objectForKey:NSFileSystemFreeSize]?:@(0) unsignedIntValue] < 7000000) {
		printf("\n");
		printf("** Requires 7MB free space in /Applications.\n");
		goto error;
	}*/
	
	
	system("chown -R 0:0 "tmpDir"/Payload/Extender.app");
	system("chmod -R 755 "tmpDir"/Payload/Extender.app");
	system("mv -f "tmpDir"/Payload/Extender.app //Applications/Ext3nder.app");
	
	rm_tmp_dir();
	
	printf("\n");
	printf("** Setting '127.0.0.1 ocsp.apple.com' to /etc/hosts.\n");
	system("sed -i -e '/ocsp.apple.com/d' /etc/hosts");
	system("echo '127.0.0.1 ocsp.apple.com' >> /etc/hosts");
	
	
	printf("\n");
	printf("** Running uicache.\n");
	system("su mobile -c uicache &>/dev/null");
	
	printf("\n");
	printf("** Respring your device!!!\n");
	printf("** Respring your device!!!\n");
	printf("** Respring your device!!!\n");
	printf("\n");
	return 0;
	
	error: {
		rm_tmp_dir();
		printf("Error: Operation Aborted...\n");
		return 1;
	}	
}