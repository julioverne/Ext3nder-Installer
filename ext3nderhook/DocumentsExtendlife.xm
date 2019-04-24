#import "Extendlife.h"
#import "CyDownUploadController.h"

static BOOL firstTimePushToDocuments;
static NSString* pathCopyMove;
extern BOOL BackgroundTranslucent;

@implementation DocumentsExtendlife
+ (id) shared {
	static __strong DocumentsExtendlife* DocumentsExtendlifeC;
	if (!DocumentsExtendlifeC) {
		DocumentsExtendlifeC = [[self alloc] init];
	}
	return DocumentsExtendlifeC;
}
@synthesize path = _path;
@synthesize files = _files;
- (NSString *)pathForFile:(NSString *)file
{
	return [self.path stringByAppendingPathComponent:file];
}
- (BOOL)fileIsDirectory:(NSString *)file
{
	BOOL isdir = NO;
	NSString *path = [self pathForFile:file];
	[[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];
	return isdir;
}
- (unsigned long long int)folderSize:(NSString *)folderPath
{	
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:folderPath error:nil];
    NSEnumerator *filesEnumerator = [filesArray objectEnumerator];
    NSString *fileName;
    unsigned long long int fileSize = 0;
    while (fileName = [filesEnumerator nextObject]) {
		@autoreleasepool {
			NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[folderPath stringByAppendingPathComponent:fileName] error:nil];
			fileSize += [fileDictionary fileSize];
		}
    }
    return fileSize;
}
- (void)Refresh
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (!self.path) {
			//self.path = @"/";
			self.path = [[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path] stringByDeletingLastPathComponent];
		}
		self.files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:nil];
		self.title = [self.path lastPathComponent];
		self.navigationItem.backBarButtonItem.title = [[self.path lastPathComponent] lastPathComponent];
		[self.tableView reloadData];
	});
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
	if(!firstTimePushToDocuments) {
		firstTimePushToDocuments = YES;
		DocumentsExtendlife *dbtvc = [[[[self class] alloc] init] initWithStyle:UITableViewStylePlain];
		dbtvc.path = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path];
		@try {
			[self.navigationController pushViewController:dbtvc animated:NO];
		} @catch (NSException * e) {
		}
		
		/*
		NSString*patFav = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path];
		
		NSString* current_pt = @"/";
		for(NSString*path_now in [patFav componentsSeparatedByString:@"/"]) {
			if(path_now && [path_now length] > 0) {
				DocumentsExtendlife *dbtvc1 = [[[[self class] alloc] init] initWithStyle:UITableViewStylePlain];
				current_pt = [current_pt stringByAppendingPathComponent:path_now];
				dbtvc1.path = current_pt;
				[self.navigationController pushViewController:dbtvc1 animated:NO];
			}
		}*/
	
	}
	
	[self Refresh];
}
- (void)loadView
{
	[super loadView];
}
- (void)viewDidLoad
{
    [super viewDidLoad];	
	if(BackgroundTranslucent) {
		self.view.alpha = 0.70;
		self.view.backgroundColor = [UIColor clearColor];
	}
	UIBarButtonItem *noButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(showOptions)];
	self.navigationItem.rightBarButtonItems = @[noButtonItem];
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
	[self Refresh];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(Refresh) name:@"com.julioverne.ext3nder/documentsChanged" object:nil];
}
- (void)showOptions
{
	UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
	[popup setContext:@"more"];
	if(pathCopyMove) {
		[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Paste" value:@"Paste" table:nil]];
	}

	[popup addButtonWithTitle:@"Import"];
	[popup addButtonWithTitle:@"WiFi Sharing"];
	[popup addButtonWithTitle:[[NSBundle mainBundle] localizedStringForKey:@"CANCEL" value:nil table:nil]];
	[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
	if (isDeviceIPad) {
		[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
	} else {
		[popup showInView:self.view];
	}
}
- (void)pushWiFiSharing
{
	@try {
		[self.navigationController pushViewController:(UIViewController*)[%c(CyDownUploadController) sharedInstance] animated:YES];
	} @catch (NSException * e) {
	}
}
- (void)refreshView:(UIRefreshControl *)refresh
{
	[self Refresh];
	[refresh endRefreshing];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.files count];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static __strong NSString *simpleTableIdentifier = @"Documents";
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
	
	NSString *file = [self.files objectAtIndex:indexPath.row];
	NSString *path = [self pathForFile:file];
	
	BOOL isdir = [self fileIsDirectory:file];
	[[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
	int size = isdir?[self folderSize:path]:[attributes[NSFileSize] intValue];
	
	cell.textLabel.text =  file;
	cell.textLabel.textColor = [attributes[NSFileType] isEqualToString:@"NSFileTypeSymbolicLink"] ? [UIColor blueColor] : [UIColor darkTextColor];
	cell.accessoryType = isdir ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
	cell.imageView.image = isdir ? [UIImage imageNamed:@"folder.png"] : [[[file pathExtension]?:@"" lowercaseString] isEqualToString:@"ipa"]?[UIImage imageNamed:@"ipa.png"]:[UIImage imageNamed:@"install.png"];
	cell.detailTextLabel.text = [NSString stringWithFormat:size>=1048576?@"%.1f MB":@"%.f KB", size>=1048576?(float)size/1048576:(float)size/1024];
	
    return cell;
}
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSString *file = [self.files objectAtIndex:indexPath.row];
	NSString *path = [self pathForFile:file];
	if ([self fileIsDirectory:file]) {
		DocumentsExtendlife *dbtvc = [[[[self class] alloc] init] initWithStyle:UITableViewStylePlain];
		dbtvc.path = path;
		@try {
			[self.navigationController pushViewController:dbtvc animated:YES];
		} @catch (NSException * e) {
		}
    } else {
		UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:file delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		
		[popup addButtonWithTitle:([getAllMails() count] > 1)?@"Sign With Account...":@"Sign"];
		[popup addButtonWithTitle:[[NSBundle mainBundle] localizedStringForKey:@"INSTALL" value:@"Install" table:nil]];
		
		[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Copy" value:@"Copy" table:nil]];
		
		[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Open In..." value:[NSString stringWithFormat:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Open in %@" value:@"Open In %@" table:nil], @"..."] table:nil]?:@"Open In..."];
		
		[popup setDestructiveButtonIndex:[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Delete" value:@"Delete" table:nil]]];
		
		[popup addButtonWithTitle:[[NSBundle mainBundle] localizedStringForKey:@"CANCEL" value:nil table:nil]];
		[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
		popup.tag = indexPath.row;
		if (isDeviceIPad) {
			[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
		} else {
			[popup showInView:self.view];
		}
	}
	return nil;
}



- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
	[controller dismissViewControllerAnimated:YES completion:nil];
	NSString* sharedDocs = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle] bundleIdentifier]] path];
	sharedDocs = [sharedDocs stringByAppendingPathComponent:@"Imported"];
	[[NSFileManager defaultManager] createDirectoryAtPath:sharedDocs withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile", NSFilePosixPermissions:@0755,} error:nil];
	
	NSString* urlPth = [url path];
	if(urlPth) {
		NSString* fileName = [urlPth lastPathComponent];
		NSURL* destURL = [NSURL fileURLWithPath:[sharedDocs stringByAppendingPathComponent:fileName]];
		NSError* error = nil;
		[[NSFileManager defaultManager] moveItemAtURL:url toURL:destURL error:&error];
		if(error!=nil) {
			showBanner([error localizedDescription], YES);
		} else {
			queueAlertBar([NSString stringWithFormat:@"File \"%@\" Imported.", fileName]);
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/documentsChanged" object:nil];
	}
	
}

- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	NSString* contextAlert = [alert context];
	NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
	
	if(contextAlert&&[contextAlert isEqualToString:@"more"]) {
		if (button == [alert cancelButtonIndex]) {
			
		} else if ([buttonTitle isEqualToString:@"WiFi Sharing"]) {
			[self pushWiFiSharing];
		} else if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Paste" value:@"Paste" table:nil]]) {
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				isInProgress = YES;
				NSString* file = [pathCopyMove lastPathComponent];
				queueAlertBar([NSString stringWithFormat:@"Copying File \"%@\".", file]);
				NSError* error = nil;
				[[NSFileManager defaultManager] copyItemAtPath:pathCopyMove toPath:[self pathForFile:file] error:&error];
				pathCopyMove = nil;
				isInProgress = NO;
				if(error!=nil) {
					showBanner([error localizedDescription], YES);
				} else {
					queueAlertBar([NSString stringWithFormat:@"File \"%@\" Copied.", file]);
				}
				[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/documentsChanged" object:nil];
			});
		} else if ([buttonTitle isEqualToString:@"Import"]) {
			NSArray *types = @[(NSString*)kUTTypeImage,(NSString*)kUTTypeSpreadsheet,(NSString*)kUTTypePresentation,(NSString*)kUTTypeDatabase,(NSString*)kUTTypeFolder,(NSString*)kUTTypeZipArchive,(NSString*)kUTTypeVideo];
			UIDocumentPickerViewController* documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeImport];
			documentPicker.delegate = self;
			[self presentViewController:documentPicker animated:YES completion:nil];
		}
	} else {
	NSString *file = self.files[[alert tag]];
	NSString *path = [self pathForFile:file];
	
	if (button == [alert cancelButtonIndex]) {
		
	} else if  (button == [alert destructiveButtonIndex]) {
		[self tableView:self.tableView commitEditingStyle:(UITableViewCellEditingStyle)0 forRowAtIndexPath:[NSIndexPath indexPathForRow:alert.tag inSection:0]];
	} else if ([buttonTitle isEqualToString:@"Sign"]) {
		signFileIpaAtPath(path);
	} else if ([buttonTitle isEqualToString:@"Sign With Account..."]) {
		UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:file delegate:(id<UIActionSheetDelegate>)self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
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
	} else if ([buttonTitle isEqualToString:[[NSBundle mainBundle] localizedStringForKey:@"INSTALL" value:@"Install" table:nil]]) {
		installFileIpaAtPath(path);
	} else if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Open In..." value:[NSString stringWithFormat:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Open in %@" value:@"Open In %@" table:nil], @"..."] table:nil]?:@"Open In..."]) {
		NSURL *url = [NSURL fileURLWithPath:path];
		UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
		[self presentViewController:avc animated:YES completion:nil];
	} else if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Copy" value:@"Copy" table:nil]]) {
		pathCopyMove = [path copy];
		queueAlertBar(@"Go To Folder & Paste.");
	} else if ([buttonTitle rangeOfString:@"@"].location != NSNotFound) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			
			setNowWorkingEmail(buttonTitle);
			NSString* storedBundleID = [[NSUserDefaults standardUserDefaults] objectForKey:[path lastPathComponent] inDomain:@"com.julioverne.ext3nder.autosign"];
			if(storedBundleID) {
				if(LSApplicationProxy* appProxy = [objc_getClass("LSApplicationProxy") applicationProxyForIdentifier:storedBundleID]) {
					NSString* withMailTeam = getTeamForEmail(buttonTitle);
					if(appProxy.teamID&&withMailTeam&&![appProxy.teamID isEqualToString:withMailTeam]) {
						isInProgress = YES;
						NSString* appName = [[appProxy localizedName] copy];
						queueAlertBar([@"Uninstalling " stringByAppendingString:appName]);
						LSApplicationWorkspace *workspace = [objc_getClass("LSApplicationWorkspace") performSelector:@selector(defaultWorkspace)];
						[workspace uninstallApplication:appProxy.applicationIdentifier withOptions:nil];
						isInProgress = NO;
						queueAlertBar([@"Uninstalled " stringByAppendingString:appName]);
					}
				}
			}
			
			[(Extender*)[UIApplication sharedApplication] application:[UIApplication sharedApplication] openURL:[NSURL fileURLWithPath:path] sourceApplication:nil annotation:nil];
		});
	}
	
	}
	
	[alert dismissWithClickedButtonIndex:0 animated:YES];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return self.path;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if(self.path&& [self.path rangeOfString:@"/Ext3nder/AutoSign"].location != NSNotFound) {
		return @"All .ipa files here will re-sign/install automatically.";
	}
	return nil;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return	YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	@try {
		NSError* error = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[self pathForFile:self.files[indexPath.row]] error:&error];
		if(error!=nil) {
			showBanner([error localizedDescription], YES);
		} else {
			queueAlertBar([NSString stringWithFormat:@"File \"%@\" Deleted.", self.files[indexPath.row]]);
		}
		[self Refresh];
	} @catch (NSException * e) {
	}
}
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Delete" value:@"Delete" table:nil];
}
- (NSURL *)navigationURL
{
	return [NSURL URLWithString:@"cyext://documents"];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 50;
}
@end

