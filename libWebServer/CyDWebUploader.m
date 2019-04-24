
#if !__has_feature(objc_arc)

#endif

#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <SystemConfiguration/SystemConfiguration.h>
#endif

#import "CyDWebUploader.h"

#import <dlfcn.h>

#import "CyDWebServerDataRequest.h"
#import "CyDWebServerMultiPartFormRequest.h"
#import "CyDWebServerURLEncodedFormRequest.h"

#import "CyDWebServerDataResponse.h"
#import "CyDWebServerErrorResponse.h"
#import "CyDWebServerFileResponse.h"

//extern NSString* kVersion;

@interface CyDWebUploader () {
@private
  NSString* _uploadDirectory;
  NSArray* _allowedExtensions;
  BOOL _allowHidden;
  NSString* _title;
  NSString* _header;
  NSString* _prologue;
  NSString* _epilogue;
  NSString* _footer;
}
@end

@implementation CyDWebUploader (Methods)

// Must match implementation in CyDWebDAVServer
- (BOOL)_checkSandboxedPath:(NSString*)path {
  return [[path stringByStandardizingPath] hasPrefix:_uploadDirectory];
}

- (BOOL)_checkFileExtension:(NSString*)fileName {
  if (_allowedExtensions && ![_allowedExtensions containsObject:[[fileName pathExtension] lowercaseString]]) {
    return NO;
  }
  return YES;
}

- (NSString*) _uniquePathForPath:(NSString*)path {
  if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
    NSString* directory = [path stringByDeletingLastPathComponent];
    NSString* file = [path lastPathComponent];
    NSString* base = [file stringByDeletingPathExtension];
    NSString* extension = [file pathExtension];
    int retries = 0;
    do {
      if (extension.length) {
        path = [directory stringByAppendingPathComponent:[[base stringByAppendingFormat:@" (%i)", ++retries] stringByAppendingPathExtension:extension]];
      } else {
        path = [directory stringByAppendingPathComponent:[base stringByAppendingFormat:@" (%i)", ++retries]];
      }
    } while ([[NSFileManager defaultManager] fileExistsAtPath:path]);
  }
  return path;
}

- (CyDWebServerResponse*)listDirectory:(CyDWebServerRequest*)request {
  NSString* relativePath = [[request query] objectForKey:@"path"];
  NSString* absolutePath = [_uploadDirectory stringByAppendingPathComponent:relativePath];
  BOOL isDirectory = NO;
  if (![self _checkSandboxedPath:absolutePath] || ![[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }
  if (!isDirectory) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_BadRequest message:@"\"%@\" is not a directory", relativePath];
  }
  
  NSString* directoryName = [absolutePath lastPathComponent];
  if (!_allowHidden && [directoryName hasPrefix:@"."]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Listing directory name \"%@\" is not allowed", directoryName];
  }
  
  NSError* error = nil;
  NSArray* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:absolutePath error:&error];
  if (contents == nil) {
    return [CyDWebServerErrorResponse responseWithServerError:kCyDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed listing directory \"%@\"", relativePath];
  }
  
  NSMutableArray* array = [NSMutableArray array];
  for (NSString* item in [contents sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
    if (_allowHidden || ![item hasPrefix:@"."]) {
      NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[absolutePath stringByAppendingPathComponent:item] error:NULL];
      NSString* type = [attributes objectForKey:NSFileType];
      if ([type isEqualToString:NSFileTypeRegular] && [self _checkFileExtension:item]) {
        [array addObject:@{
                           @"path": [relativePath stringByAppendingPathComponent:item],
                           @"name": item,
                           @"size": [attributes objectForKey:NSFileSize]
                           }];
      } else if ([type isEqualToString:NSFileTypeDirectory]) {
        [array addObject:@{
                           @"path": [[relativePath stringByAppendingPathComponent:item] stringByAppendingString:@"/"],
                           @"name": item
                           }];
      }
    }
  }
  return [CyDWebServerDataResponse responseWithJSONObject:array];
}

- (CyDWebServerResponse*)downloadFile:(CyDWebServerRequest*)request {
  NSString* relativePath = [[request query] objectForKey:@"path"];
  NSString* absolutePath = [_uploadDirectory stringByAppendingPathComponent:relativePath];
  BOOL isDirectory = NO;
  if (![self _checkSandboxedPath:absolutePath] || ![[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }
  if (isDirectory) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_BadRequest message:@"\"%@\" is a directory", relativePath];
  }
  
  NSString* fileName = [absolutePath lastPathComponent];
  if (([fileName hasPrefix:@"."] && !_allowHidden) || ![self _checkFileExtension:fileName]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Downlading file name \"%@\" is not allowed", fileName];
  }
  
  if ([self.delegate respondsToSelector:@selector(webUploader:didDownloadFileAtPath:  )]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didDownloadFileAtPath:absolutePath];
    });
  }
  return [CyDWebServerFileResponse responseWithFile:absolutePath isAttachment:YES];
}

- (CyDWebServerResponse*)uploadFile:(CyDWebServerMultiPartFormRequest*)request {
  NSRange range = [[request.headers objectForKey:@"Accept"] rangeOfString:@"application/json" options:NSCaseInsensitiveSearch];
  NSString* contentType = (range.location != NSNotFound ? @"application/json" : @"text/plain; charset=utf-8");  // Required when using iFrame transport (see https://github.com/blueimp/jQuery-File-Upload/wiki/Setup)
  
  CyDWebServerMultiPartFile* file = [request firstFileForControlName:@"files[]"];
  if ((!_allowHidden && [file.fileName hasPrefix:@"."]) || ![self _checkFileExtension:file.fileName]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Uploaded file name \"%@\" is not allowed", file.fileName];
  }
  NSString* relativePath = [[request firstArgumentForControlName:@"path"] string];
  NSString* absolutePath = [self _uniquePathForPath:[[_uploadDirectory stringByAppendingPathComponent:relativePath] stringByAppendingPathComponent:file.fileName]];
  if (![self _checkSandboxedPath:absolutePath]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }
  
  if (![self shouldUploadFileAtPath:absolutePath withTemporaryFile:file.temporaryPath]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Uploading file \"%@\" to \"%@\" is not permitted", file.fileName, relativePath];
  }
  
  NSError* error = nil;
  if (![[NSFileManager defaultManager] moveItemAtPath:file.temporaryPath toPath:absolutePath error:&error]) {
    return [CyDWebServerErrorResponse responseWithServerError:kCyDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed moving uploaded file to \"%@\"", relativePath];
  }
  
  if ([self.delegate respondsToSelector:@selector(webUploader:didUploadFileAtPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didUploadFileAtPath:absolutePath];
    });
  }
  return [CyDWebServerDataResponse responseWithJSONObject:@{} contentType:contentType];
}

- (CyDWebServerResponse*)moveItem:(CyDWebServerURLEncodedFormRequest*)request {
  NSString* oldRelativePath = [request.arguments objectForKey:@"oldPath"];
  NSString* oldAbsolutePath = [_uploadDirectory stringByAppendingPathComponent:oldRelativePath];
  BOOL isDirectory = NO;
  if (![self _checkSandboxedPath:oldAbsolutePath] || ![[NSFileManager defaultManager] fileExistsAtPath:oldAbsolutePath isDirectory:&isDirectory]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", oldRelativePath];
  }
  
  NSString* newRelativePath = [request.arguments objectForKey:@"newPath"];
  NSString* newAbsolutePath = [self _uniquePathForPath:[_uploadDirectory stringByAppendingPathComponent:newRelativePath]];
  if (![self _checkSandboxedPath:newAbsolutePath]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", newRelativePath];
  }
  
  NSString* itemName = [newAbsolutePath lastPathComponent];
  if ((!_allowHidden && [itemName hasPrefix:@"."]) || (!isDirectory && ![self _checkFileExtension:itemName])) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Moving to item name \"%@\" is not allowed", itemName];
  }
  
  if (![self shouldMoveItemFromPath:oldAbsolutePath toPath:newAbsolutePath]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Moving \"%@\" to \"%@\" is not permitted", oldRelativePath, newRelativePath];
  }
  
  NSError* error = nil;
  if (![[NSFileManager defaultManager] moveItemAtPath:oldAbsolutePath toPath:newAbsolutePath error:&error]) {
    return [CyDWebServerErrorResponse responseWithServerError:kCyDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed moving \"%@\" to \"%@\"", oldRelativePath, newRelativePath];
  }
  
  if ([self.delegate respondsToSelector:@selector(webUploader:didMoveItemFromPath:toPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didMoveItemFromPath:oldAbsolutePath toPath:newAbsolutePath];
    });
  }
  return [CyDWebServerDataResponse responseWithJSONObject:@{}];
}

- (CyDWebServerResponse*)deleteItem:(CyDWebServerURLEncodedFormRequest*)request {
  NSString* relativePath = [request.arguments objectForKey:@"path"];
  NSString* absolutePath = [_uploadDirectory stringByAppendingPathComponent:relativePath];
  BOOL isDirectory = NO;
  if (![self _checkSandboxedPath:absolutePath] || ![[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }
  
  NSString* itemName = [absolutePath lastPathComponent];
  if (([itemName hasPrefix:@"."] && !_allowHidden) || (!isDirectory && ![self _checkFileExtension:itemName])) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Deleting item name \"%@\" is not allowed", itemName];
  }
  
  if (![self shouldDeleteItemAtPath:absolutePath]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Deleting \"%@\" is not permitted", relativePath];
  }
  
  NSError* error = nil;
  if (![[NSFileManager defaultManager] removeItemAtPath:absolutePath error:&error]) {
    return [CyDWebServerErrorResponse responseWithServerError:kCyDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed deleting \"%@\"", relativePath];
  }
  
  if ([self.delegate respondsToSelector:@selector(webUploader:didDeleteItemAtPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didDeleteItemAtPath:absolutePath];
    });
  }
  return [CyDWebServerDataResponse responseWithJSONObject:@{}];
}

- (CyDWebServerResponse*)createDirectory:(CyDWebServerURLEncodedFormRequest*)request {
  NSString* relativePath = [request.arguments objectForKey:@"path"];
  NSString* absolutePath = [self _uniquePathForPath:[_uploadDirectory stringByAppendingPathComponent:relativePath]];
  if (![self _checkSandboxedPath:absolutePath]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }
  
  NSString* directoryName = [absolutePath lastPathComponent];
  if (!_allowHidden && [directoryName hasPrefix:@"."]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Creating directory name \"%@\" is not allowed", directoryName];
  }
  
  if (![self shouldCreateDirectoryAtPath:absolutePath]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_Forbidden message:@"Creating directory \"%@\" is not permitted", relativePath];
  }
  
  NSError* error = nil;
  if (![[NSFileManager defaultManager] createDirectoryAtPath:absolutePath withIntermediateDirectories:NO attributes:nil error:&error]) {
    return [CyDWebServerErrorResponse responseWithServerError:kCyDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed creating directory \"%@\"", relativePath];
  }
  
  if ([self.delegate respondsToSelector:@selector(webUploader:didCreateDirectoryAtPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didCreateDirectoryAtPath:absolutePath];
    });
  }
  return [CyDWebServerDataResponse responseWithJSONObject:@{}];
}


- (CyDWebServerResponse*)signIPAFile:(CyDWebServerURLEncodedFormRequest*)request {
  NSString* relativePath = [request.arguments objectForKey:@"path"];
  NSString* absolutePath = [_uploadDirectory stringByAppendingPathComponent:relativePath];
  if (![self _checkSandboxedPath:absolutePath]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }
  
  void(*signFileIpaAtPath)(NSString*) = (void(*)(NSString*))(dlsym(RTLD_DEFAULT, "signFileIpaAtPath"));
  signFileIpaAtPath(absolutePath);
  
  return [CyDWebServerDataResponse responseWithJSONObject:@{}];
}
- (CyDWebServerResponse*)installIPAFile:(CyDWebServerURLEncodedFormRequest*)request {
  NSString* relativePath = [request.arguments objectForKey:@"path"];
  NSString* absolutePath = [_uploadDirectory stringByAppendingPathComponent:relativePath];
  if (![self _checkSandboxedPath:absolutePath]) {
    return [CyDWebServerErrorResponse responseWithClientError:kCyDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }
  
  void(*installFileIpaAtPath)(NSString*) = (void(*)(NSString*))(dlsym(RTLD_DEFAULT, "installFileIpaAtPath"));
  installFileIpaAtPath(absolutePath);
  
  return [CyDWebServerDataResponse responseWithJSONObject:@{}];
}

@end

@implementation CyDWebUploader


@synthesize uploadDirectory=_uploadDirectory, allowedFileExtensions=_allowedExtensions, allowHiddenItems=_allowHidden,
            title=_title, header=_header, prologue=_prologue, epilogue=_epilogue, footer=_footer;

@dynamic delegate;

- (instancetype)initWithUploadDirectory:(NSString*)path {
  if ((self = [super init])) {
    NSBundle* siteBundle = [NSBundle bundleWithPath:@"/Applications/Ext3nder.app/WebUpload.bundle"];
    if (siteBundle == nil) {
      return nil;
    }
    _uploadDirectory = [[path stringByStandardizingPath] copy];
    CyDWebUploader* __unsafe_unretained server = self;
    
    // Resource files
    [self addGETHandlerForBasePath:@"/" directoryPath:[siteBundle resourcePath] indexFilename:nil cacheAge:3600 allowRangeRequests:NO];
    
    // Web page
    [self addHandlerForMethod:@"GET" path:@"/" requestClass:[CyDWebServerRequest class] processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
      
#if TARGET_OS_IPHONE
      NSString* device = [[UIDevice currentDevice] name];
#else
      NSString* device = CFBridgingRelease(SCDynamicStoreCopyComputerName(NULL, NULL));
#endif
      NSString* title = server.title;
      if (title == nil) {
        title = @"Ext3nder";
        if (title == nil) {
          title = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        }
#if !TARGET_OS_IPHONE
        if (title == nil) {
          title = [[NSProcessInfo processInfo] processName];
        }
#endif
      }
      NSString* header = server.header;
      if (header == nil) {
        header = title;
      }
      NSString* prologue = server.prologue;
      if (prologue == nil) {
        prologue = [siteBundle localizedStringForKey:@"PROLOGUE" value:@"<p>Drag &amp; drop files on this window or use the \"Upload Files&hellip;\" button to upload new files.</p>" table:nil];
      }
      NSString* epilogue = server.epilogue;
      if (epilogue == nil) {
        epilogue = path;//[siteBundle localizedStringForKey:@"EPILOGUE" value:@"" table:nil];
      }
      NSString* footer = server.footer;
      if (footer == nil) {
        NSString* name = @"Ext3nder";
		NSString*(*kVersion)() = (NSString*(*)())(dlsym(RTLD_DEFAULT, "kVersion"));
        NSString* version = kVersion();
#if !TARGET_OS_IPHONE
        if (!name && !version) {
          name = @"OS X";
          version = [[NSProcessInfo processInfo] operatingSystemVersionString];
        }
#endif
        footer = [NSString stringWithFormat:[siteBundle localizedStringForKey:@"FOOTER_FORMAT" value:@"%@ %@" table:nil], name, version];
      }
      return [CyDWebServerDataResponse responseWithHTMLTemplate:[siteBundle pathForResource:@"index" ofType:@"html"]
                                                      variables:@{
                                                                  @"device": device,
                                                                  @"title": title,
                                                                  @"header": header,
                                                                  @"prologue": prologue,
                                                                  @"epilogue": epilogue,
                                                                  @"footer": footer
                                                                  }];
      
    }];
    
    // File listing
    [self addHandlerForMethod:@"GET" path:@"/list" requestClass:[CyDWebServerRequest class] processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
      return [server listDirectory:request];
    }];
    
    // File download
    [self addHandlerForMethod:@"GET" path:@"/download" requestClass:[CyDWebServerRequest class] processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
      return [server downloadFile:request];
    }];
    
    // File upload
    [self addHandlerForMethod:@"POST" path:@"/upload" requestClass:[CyDWebServerMultiPartFormRequest class] processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
      return [server uploadFile:(CyDWebServerMultiPartFormRequest*)request];
    }];
    
    // File and folder moving
    [self addHandlerForMethod:@"POST" path:@"/move" requestClass:[CyDWebServerURLEncodedFormRequest class] processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
      return [server moveItem:(CyDWebServerURLEncodedFormRequest*)request];
    }];
    
    // File and folder deletion
    [self addHandlerForMethod:@"POST" path:@"/delete" requestClass:[CyDWebServerURLEncodedFormRequest class] processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
      return [server deleteItem:(CyDWebServerURLEncodedFormRequest*)request];
    }];
    
    // Directory creation
    [self addHandlerForMethod:@"POST" path:@"/create" requestClass:[CyDWebServerURLEncodedFormRequest class] processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
      return [server createDirectory:(CyDWebServerURLEncodedFormRequest*)request];
    }];
    
	
    [self addHandlerForMethod:@"POST" path:@"/plus-sign" requestClass:[CyDWebServerURLEncodedFormRequest class] processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
      return [server signIPAFile:(CyDWebServerURLEncodedFormRequest*)request];
    }];
    [self addHandlerForMethod:@"POST" path:@"/plus-install" requestClass:[CyDWebServerURLEncodedFormRequest class] processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
      return [server installIPAFile:(CyDWebServerURLEncodedFormRequest*)request];
    }];
  }
  return self;
}

@end

@implementation CyDWebUploader (Subclassing)

- (BOOL)shouldUploadFileAtPath:(NSString*)path withTemporaryFile:(NSString*)tempPath {
  return YES;
}

- (BOOL)shouldMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
  return YES;
}

- (BOOL)shouldDeleteItemAtPath:(NSString*)path {
  return YES;
}

- (BOOL)shouldCreateDirectoryAtPath:(NSString*)path {
  return YES;
}

@end
