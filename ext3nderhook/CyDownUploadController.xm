
#import "Extendlife.h"
#import "CyDownUploadController.h"
#import "../libWebServer/CyDWebUploader.h"

@interface CyDownUploadController () <CyDWebUploaderDelegate>
@end


@implementation CyDownUploadController
{
	CyDWebUploader* _webServer;
}

+ (instancetype)sharedInstance
{
	static __strong CyDownUploadController* _shared;
	if(!_shared) {
		_shared = [[[self class] alloc] initWithStyle:UITableViewStyleGrouped];
	}
	return _shared;
}

- (id)initWithStyle:(UITableViewStyle)style
{
	if(self = [super initWithStyle:style]) {
		dlopen("/Applications/Ext3nder.app/WebUpload.bundle/libWebServer.dylib", RTLD_GLOBAL);
		if(!_webServer) {
			static __strong NSString* kDocs = @"//var/mobile/Documents/Ext3nder/";
			_webServer = [[%c(CyDWebUploader) alloc] initWithUploadDirectory:kDocs];
			_webServer.delegate = self;
			_webServer.allowHiddenItems = YES;
		}
	}
	return self;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static __strong NSString* simpleTableIdentifier = @"Ext3nder";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
	}
	cell.accessoryType = UITableViewCellAccessoryNone;
	[cell setSelectionStyle:UITableViewCellSelectionStyleNone];
	cell.accessoryView = nil;
	cell.imageView.image = nil;
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	cell.textLabel.textColor = [UIColor blackColor];
	
	if ([indexPath section] == 0) {
		if (indexPath.row == 0) {
			cell.textLabel.text = @"Enabled";
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
			cell.accessoryView = switchView;
			[switchView setOn:_webServer.running animated:NO];
			[switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
		}
	}
	
	return cell;
}

- (void)switchChanged:(id)sender
{
    UISwitch* switchControl = sender;
	if(switchControl.on) {
		if ([_webServer start]) {
			
		}
	} else {
		[_webServer stop];
	}
	[self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0) {
		return 1;
	}
	return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if (section == 0) {
		if(_webServer.running) {
			return [NSString stringWithFormat:@"Wi-Fi Sharing running at: %@", _webServer.serverURL];
		}
	}
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.title = @"Wi-Fi Sharing";
	[self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (void)webUploader:(CyDWebUploader*)uploader didUploadFileAtPath:(NSString*)path
{
	showBanner([NSString stringWithFormat:@"File \"%@\" %@ via WiFi Sharing.", [path lastPathComponent], @"Received"], NO);
	[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/documentsChanged" object:nil];
}
- (void)webUploader:(CyDWebUploader*)uploader didDeleteItemAtPath:(NSString*)path
{
	showBanner([NSString stringWithFormat:@"File \"%@\" %@ via WiFi Sharing.", [path lastPathComponent], @"Deleted"], NO);
	[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/documentsChanged" object:nil];
}
- (void)webUploader:(CyDWebUploader*)uploader didCreateDirectoryAtPath:(NSString*)path
{
	showBanner([NSString stringWithFormat:@"File \"%@\" %@ via WiFi Sharing.", [path lastPathComponent], @"Created"], NO);
	[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/documentsChanged" object:nil];
}
- (void)webUploader:(CyDWebUploader*)uploader didMoveItemFromPath:(NSString*)path toPath:(NSString*)toPath
{
	showBanner([NSString stringWithFormat:@"File \"%@\" %@ via WiFi Sharing.", [toPath lastPathComponent], @"Moved"], NO);
	[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.ext3nder/documentsChanged" object:nil];
}

@end
