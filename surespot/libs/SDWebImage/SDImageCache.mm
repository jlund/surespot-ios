/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageCache.h"
#import "SDWebImageDecoder.h"
#import "UIImage+MultiFormat.h"
#import <CommonCrypto/CommonDigest.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import "CredentialCachingController.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7; // 1 week
// PNG signature bytes and data (below)
static unsigned char kPNGSignatureBytes[8] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
static NSData *kPNGSignatureData = nil;

BOOL ImageDataHasPNGPreffix(NSData *data);
BOOL ImageDataHasPNGPreffix(NSData *data)
{
    NSUInteger pngSignatureLength = [kPNGSignatureData length];
    if ([data length] >= pngSignatureLength)
    {
        if ([[data subdataWithRange:NSMakeRange(0, pngSignatureLength)] isEqualToData:kPNGSignatureData])
        {
            return YES;
        }
    }
    
    return NO;
}

@interface SDImageCache ()

@property (strong, nonatomic) NSCache *memCache;
@property (strong, nonatomic) NSString *diskCachePath;
@property (strong, nonatomic) NSMutableArray *customPaths;
@property (SDDispatchQueueSetterSementics, nonatomic) dispatch_queue_t ioQueue;

@end


@implementation SDImageCache
{
    NSFileManager *_fileManager;
}

+ (SDImageCache *)sharedImageCache
{
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^
                  {
                      instance = [self new];
                      kPNGSignatureData = [NSData dataWithBytes:kPNGSignatureBytes length:8];
                  });
    return instance;
}

- (id)init
{
    return [self initWithNamespace:@"default"];
}

- (id)initWithNamespace:(NSString *)ns
{
    if ((self = [super init]))
    {
        NSString *fullNamespace = [@"com.hackemist.SDWebImageCache." stringByAppendingString:ns];
        
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.hackemist.SDWebImageCache", DISPATCH_QUEUE_SERIAL);
        
        // Init default values
        _maxCacheAge = kDefaultCacheMaxCacheAge;
        
        // Init the memory cache
        _memCache = [[NSCache alloc] init];
        _memCache.name = fullNamespace;
        
        // Init the disk cache
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _diskCachePath = [paths[0] stringByAppendingPathComponent:fullNamespace];
        
        dispatch_sync(_ioQueue, ^
                      {
                          _fileManager = [NSFileManager new];
                      });
        
#if TARGET_OS_IPHONE
        // Subscribe to app events
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanDisk)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundCleanDisk)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SDDispatchQueueRelease(_ioQueue);
}

- (void)addReadOnlyCachePath:(NSString *)path
{
    if (!self.customPaths)
    {
        self.customPaths = [NSMutableArray new];
    }
    
    if (![self.customPaths containsObject:path])
    {
        [self.customPaths addObject:path];
    }
}

#pragma mark SDImageCache (private)

- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path
{
    NSString *filename = [self cachedFileNameForKey:key];
    return [path stringByAppendingPathComponent:filename];
}

- (NSString *)defaultCachePathForKey:(NSString *)key
{
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

- (NSString *)cachedFileNameForKey:(NSString *)key
{
    const char *str = [key UTF8String];
    if (str == NULL)
    {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
    
    return filename;
}

#pragma mark ImageCache

- (void)storeImage:(id)image imageData:(NSData *)imageData mimeType: (NSString *) mimeType forKey:(NSString *)key toDisk:(BOOL)toDisk
{
    if (!image || !key)
    {
        return;
    }
    
    DDLogInfo(@"storing image in memory cache at key: %@", key);
    CGFloat cost = 0;
    
    if ([mimeType isEqualToString:MIME_TYPE_IMAGE]) {
        
        cost = [image size].height * [image size].width * [(UIImage *)image scale];
    }
    else if ([mimeType isEqualToString:MIME_TYPE_M4A]){
        cost = [image length];
    }
    
    DDLogInfo(@"using image from disk cache for key: %@", key);
    [self.memCache setObject:image forKey:key cost:cost];
    
    if (toDisk)
    {
        dispatch_async(self.ioQueue, ^
                       {
                           if (imageData)
                           {
                               // Can't use defaultManager another thread
                               NSFileManager *fileManager = [NSFileManager new];
                               
                               if (![fileManager fileExistsAtPath:_diskCachePath])
                               {
                                   [fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
                               }
                               
                               NSString * path = [self defaultCachePathForKey:key];
                               [fileManager createFileAtPath:path contents:imageData attributes:nil];
                               DDLogInfo(@"storing encrypted image data to disk at %@ for key: %@", path,  key);
                           }
                       });
    }
}

-(BOOL) isKeyCached: (NSString *) key {
    if ([self imageFromMemoryCacheForKey:key]) {
        return YES;
    }
    
    NSString *defaultPath = [self defaultCachePathForKey:key];
    return [[NSFileManager defaultManager] fileExistsAtPath:defaultPath];
}

- (BOOL)diskImageExistsWithKey:(NSString *)key
{
    __block BOOL exists = NO;
    dispatch_sync(_ioQueue, ^
                  {
                      exists = [_fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];
                  });
    
    return exists;
}

- (id)imageFromMemoryCacheForKey:(NSString *)key
{
    
    return [self.memCache objectForKey:key];
}

- (id)imageFromDiskCacheForKey:(NSString *)key mimeType: (NSString *) mimeType encryptionKey:(NSData *) encryptionKey iv: (NSString *) iv
{
    // First check the in-memory cache...
    id image = [self imageFromMemoryCacheForKey:key];
    if (image)
    {
        DDLogInfo(@"using image from memory cache for key: %@", key);
        return image;
    }
    
    // Second check the disk cache...
    id diskImage = [self diskImageForCacheKey:key mimeType: mimeType encryptionKey:encryptionKey iv:iv];
    CGFloat cost = 0;
    if (diskImage)
    {
        DDLogInfo(@"using image from disk cache for key: %@", key);
        if ([mimeType isEqualToString:MIME_TYPE_IMAGE]) {
            
            
            cost = [diskImage size].height * [diskImage size].width * [(UIImage *)diskImage scale];
        }
        else if ([mimeType isEqualToString:MIME_TYPE_M4A]){
            cost = [diskImage length];
        }
        
        
        [self.memCache setObject:diskImage forKey:key cost:cost];
    }
    
    return diskImage;
}

- (NSData *)diskImageDataBySearchingAllPathsForKey:(NSString *)key
{
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    if (data)
    {
        return data;
    }
    
    for (NSString *path in self.customPaths)
    {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath];
        if (imageData) {
            return imageData;
        }
    }
    
    return nil;
}

- (id) diskImageForCacheKey:(NSString *)cacheKey mimeType: (NSString *) mimeType encryptionKey:(NSData *) encryptionKey iv: (NSString *) iv
{
    NSData *data = [self diskImageDataBySearchingAllPathsForKey:cacheKey];
    if (data)
    {
        if ([mimeType isEqualToString:MIME_TYPE_IMAGE]) {
            //        UIImage *image = [self scaledImageForKey:cacheKey image:[UIImage sd_imageWithEncryptedData:data key:encryptionKey iv:iv]];
            UIImage *image = [UIImage sd_imageWithEncryptedData:data key:encryptionKey iv:iv];
            image = [UIImage decodedImageWithImage:image];
            return image;
        }
        else {
            if ([mimeType isEqualToString:MIME_TYPE_M4A]) {
                return [EncryptionController symmetricDecryptData:data key:encryptionKey iv:iv];
            }
            else {
                return nil;
            }
        }
    }
    else
    {
        return nil;
    }
}

- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image
{
    return SDScaledImageForKey(key, image);
}

- (NSOperation *)queryDiskCacheForKey:(NSString *) key
                             mimeType:(NSString *) mimeType
                           ourVersion:(NSString *) ourversion
                        theirUsername:(NSString *) theirUsername
                         theirVersion:(NSString *) theirVersion
                                   iv:(NSString *) iv
                                 done:(void (^)(id image, SDImageCacheType cacheType))doneBlock
{
    NSOperation *operation = [NSOperation new];
    
    if (!doneBlock) return nil;
    
    if (!key|| !ourversion || !theirVersion || !theirUsername || !iv)
    {
        doneBlock(nil, SDImageCacheTypeNone);
        return nil;
    }
    
    // First check the in-memory cache...
    id image = [self imageFromMemoryCacheForKey:key];
    if (image)
    {
        DDLogInfo(@"using image from memory cache for key: %@", key);
        doneBlock(image, SDImageCacheTypeMemory);
        return nil;
    }
    
    dispatch_async(self.ioQueue, ^
                   {
                       if (operation.isCancelled)
                       {
                           return;
                       }
                       
                       @autoreleasepool
                       {
                           
                           [[CredentialCachingController sharedInstance] getSharedSecretForOurVersion:ourversion theirUsername:theirUsername theirVersion:theirVersion callback:^(id encryptionKey) {
                               
                               id diskImage = nil;
                               
                               if (encryptionKey) {
                                   diskImage = [self diskImageForCacheKey:key mimeType: mimeType encryptionKey:encryptionKey iv:iv];
                               }
                               
                               CGFloat cost = 0;
                               if (diskImage)
                               {
                                   DDLogInfo(@"using image from disk cache and setting memory cache for key: %@", key);
                                   if ([mimeType isEqualToString:MIME_TYPE_IMAGE]) {
                                       
                                       cost = [diskImage size].height * [diskImage size].width * [(UIImage *)diskImage scale];
                                   }
                                   else {
                                       if ([mimeType isEqualToString:MIME_TYPE_M4A]) {
                                           cost = [diskImage length];
                                       }
                                   }
                                   [self.memCache setObject:diskImage forKey:key cost:cost];
                               }
                               
                               
                               dispatch_main_sync_safe(^
                                                       {
                                                           doneBlock(diskImage, SDImageCacheTypeDisk);
                                                       });
                               
                               
                           }];
                       }
                   });
    
    return operation;
}

- (void)removeImageForKey:(NSString *)key
{
    [self removeImageForKey:key fromDisk:YES];
}

- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk
{
    if (key == nil)
    {
        return;
    }
    
    [self.memCache removeObjectForKey:key];
    
    if (fromDisk)
    {
        dispatch_async(self.ioQueue, ^
                       {
                           [[NSFileManager defaultManager] removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
                       });
    }
}

- (void)setMaxMemoryCost:(NSUInteger)maxMemoryCost
{
    self.memCache.totalCostLimit = maxMemoryCost;
}

- (NSUInteger)maxMemoryCost
{
    return self.memCache.totalCostLimit;
}

- (void)clearMemory
{
    [self.memCache removeAllObjects];
}

- (void)clearDisk
{
    dispatch_async(self.ioQueue, ^
                   {
                       [[NSFileManager defaultManager] removeItemAtPath:self.diskCachePath error:nil];
                       [[NSFileManager defaultManager] createDirectoryAtPath:self.diskCachePath
                                                 withIntermediateDirectories:YES
                                                                  attributes:nil
                                                                       error:NULL];
                   });
}

- (void)cleanDisk
{
    dispatch_async(self.ioQueue, ^
                   {
                       NSFileManager *fileManager = [NSFileManager defaultManager];
                       NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
                       NSArray *resourceKeys = @[ NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey ];
                       
                       // This enumerator prefetches useful properties for our cache files.
                       NSDirectoryEnumerator *fileEnumerator = [fileManager enumeratorAtURL:diskCacheURL
                                                                 includingPropertiesForKeys:resourceKeys
                                                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                               errorHandler:NULL];
                       
                       NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
                       NSMutableDictionary *cacheFiles = [NSMutableDictionary dictionary];
                       unsigned long long currentCacheSize = 0;
                       
                       // Enumerate all of the files in the cache directory.  This loop has two purposes:
                       //
                       //  1. Removing files that are older than the expiration date.
                       //  2. Storing file attributes for the size-based cleanup pass.
                       for (NSURL *fileURL in fileEnumerator)
                       {
                           NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];
                           
                           // Skip directories.
                           if ([resourceValues[NSURLIsDirectoryKey] boolValue])
                           {
                               continue;
                           }
                           
                           // Remove files that are older than the expiration date;
                           NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
                           if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate])
                           {
                               [fileManager removeItemAtURL:fileURL error:nil];
                               continue;
                           }
                           
                           // Store a reference to this file and account for its total size.
                           NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                           currentCacheSize += [totalAllocatedSize unsignedLongLongValue];
                           [cacheFiles setObject:resourceValues forKey:fileURL];
                       }
                       
                       // If our remaining disk cache exceeds a configured maximum size, perform a second
                       // size-based cleanup pass.  We delete the oldest files first.
                       if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize)
                       {
                           // Target half of our maximum cache size for this cleanup pass.
                           const unsigned long long desiredCacheSize = self.maxCacheSize / 2;
                           
                           // Sort the remaining cache files by their last modification time (oldest first).
                           NSArray *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                           usingComparator:^NSComparisonResult(id obj1, id obj2)
                                                   {
                                                       return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                   }];
                           
                           // Delete files until we fall below our desired cache size.
                           for (NSURL *fileURL in sortedFiles)
                           {
                               if ([fileManager removeItemAtURL:fileURL error:nil])
                               {
                                   NSDictionary *resourceValues = cacheFiles[fileURL];
                                   NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                                   currentCacheSize -= [totalAllocatedSize unsignedLongLongValue];
                                   
                                   if (currentCacheSize < desiredCacheSize)
                                   {
                                       break;
                                   }
                               }
                           }
                       }
                   });
}

- (void)backgroundCleanDisk
{
    UIApplication *application = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^
                                                 {
                                                     // Clean up any unfinished task business by marking where you
                                                     // stopped or ending the task outright.
                                                     [application endBackgroundTask:bgTask];
                                                     bgTask = UIBackgroundTaskInvalid;
                                                 }];
    
    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
                   {
                       // Do the work associated with the task, preferably in chunks.
                       [self cleanDisk];
                       
                       [application endBackgroundTask:bgTask];
                       bgTask = UIBackgroundTaskInvalid;
                   });
}

- (unsigned long long)getSize
{
    unsigned long long size = 0;
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:self.diskCachePath];
    for (NSString *fileName in fileEnumerator)
    {
        NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        size += [attrs fileSize];
    }
    return size;
}

- (int)getDiskCount
{
    int count = 0;
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:self.diskCachePath];
    for (NSString *fileName in fileEnumerator)
    {
        count += 1;
    }
    
    return count;
}

- (void)calculateSizeWithCompletionBlock:(void (^)(NSUInteger fileCount, unsigned long long totalSize))completionBlock
{
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^
                   {
                       NSUInteger fileCount = 0;
                       unsigned long long totalSize = 0;
                       
                       NSFileManager *fileManager = [NSFileManager defaultManager];
                       NSDirectoryEnumerator *fileEnumerator = [fileManager enumeratorAtURL:diskCacheURL
                                                                 includingPropertiesForKeys:@[ NSFileSize ]
                                                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                               errorHandler:NULL];
                       
                       for (NSURL *fileURL in fileEnumerator)
                       {
                           NSNumber *fileSize;
                           [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
                           totalSize += [fileSize unsignedLongLongValue];
                           fileCount += 1;
                       }
                       
                       if (completionBlock)
                       {
                           dispatch_main_sync_safe(^
                                                   {
                                                       completionBlock(fileCount, totalSize);
                                                   });
                       }
                   });
}

@end
