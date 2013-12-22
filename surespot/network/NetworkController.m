//
//  NetworkController.m
//  surespot
//
//  Created by Adam on 6/16/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "NetworkController.h"
#import "ChatUtils.h"
#import "DDLog.h"
#import "SurespotConstants.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface NetworkController()
@property (nonatomic, strong) NSString * baseUrl;
@property (atomic, assign) BOOL loggedOut;
@end

@implementation NetworkController

+(NetworkController*)sharedInstance
{
    static NetworkController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
        
    });
    
    return sharedInstance;
}

-(NetworkController*)init
{
    NSString * baseUrl = serverSecure ?
    [NSString stringWithFormat: @"https://%@:%d", serverBaseIPAddress, serverPort] :
    [NSString stringWithFormat: @"http://%@:%d", serverBaseIPAddress, serverPort];
    
    //call super init
    self = [super initWithBaseURL:[NSURL URLWithString: baseUrl]];
    
    if (self != nil) {
        _baseUrl = baseUrl;
        
        //   [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        //  [self registerHTTPOperationClass:[AFHTTPRequestOperation class]];
        
        
        // Accept HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
        [self setDefaultHeader:@"Accept-Charset" value:@"utf-8"];
        //[self setDefaultHeader:@"Accept" value:@"application/json"];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(HTTPOperationDidFinish:) name:AFNetworkingOperationDidFinishNotification object:nil];
        
        self.parameterEncoding = AFJSONParameterEncoding;
    }
    
    return self;
}


//handle 401s globally
- (void)HTTPOperationDidFinish:(NSNotification *)notification {
    AFHTTPRequestOperation *operation = (AFHTTPRequestOperation *)[notification object];
    
    if (![operation isKindOfClass:[AFHTTPRequestOperation class]]) {
        return;
    }
    
    if ([operation.response statusCode] == 401) {
        DDLogInfo(@"path components: %@", operation.request.URL.pathComponents[1]);
        //ignore on logout
        if (![operation.request.URL.pathComponents[1] isEqualToString:@"logout"]) {
            DDLogInfo(@"received 401");
            [self setUnauthorized];
        }
        else {
            DDLogInfo(@"logout 401'd");
        }
    }
}

-(void) setUnauthorized {
    _loggedOut = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"unauthorized" object: nil];
}

-(void) loginWithUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
             successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock
{
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   versionString, @"version",
                                   @"ios", @"platform", nil];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"login" parameters: params];
    
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        BOOL gotCookie = [self extractConnectCookie];
        if (gotCookie) {
            successBlock(request, response, JSON);
        }
        else {
            failureBlock(request, response, nil, nil);
        }
        
        
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        failureBlock(request, response, error, JSON);
    } ];
    
    
    [operation start];
    
}


-(void) addUser: (NSString *) username derivedPassword:  (NSString *)derivedPassword dhKey: (NSString *)encodedDHKey dsaKey: (NSString *)encodedDSAKey signature: (NSString *)signature successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   derivedPassword,@"password",
                                   signature, @"authSig",
                                   encodedDHKey, @"dhPub",
                                   encodedDSAKey, @"dsaPub",
                                   versionString, @"version",
                                   @"ios", @"platform", nil];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"users" parameters: params];
    
    
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        BOOL gotCookie = [self extractConnectCookie];
        if (gotCookie) {
            successBlock(operation, responseObject);
        }
        else {
            failureBlock(operation, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failureBlock(operation, error);
    }];
    
    [operation start];
}


-(BOOL) extractConnectCookie {
    //save the cookie
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:_baseUrl]];
    
    NSHTTPCookie * surespotCookie;
    for (NSHTTPCookie *cookie in cookies)
    {
        if ([cookie.name isEqualToString:@"connect.sid"]) {
            _loggedOut = NO;
            surespotCookie = cookie;
            return YES;
        }
    }
    
    return NO;
    
}

-(void) getFriendsSuccessBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"friends" parameters:nil];
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock
                                                                                        failure: failureBlock];
    operation.JSONReadingOptions = NSJSONReadingMutableContainers;
    [operation start];
}

-(void) inviteFriend: (NSString *) friendname successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat: @"invite/%@",friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"POST" path:path parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

- (void) getKeyVersionForUsername:(NSString *)username successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock
{
    NSString * path = [[NSString stringWithFormat: @"keyversion/%@",username] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters: nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

- (void) getPublicKeysForUsername:(NSString *)username andVersion:(NSString *)version successBlock:(JSONSuccessBlock)successBlock failureBlock:(JSONFailureBlock) failureBlock{
    NSURLRequest *request = [self buildPublicKeyRequestForUsername:username version:version];
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure: failureBlock];
    
    //dont't need this on main thread
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    [operation start];
}

-(NSURLRequest *) buildPublicKeyRequestForUsername: (NSString *) username version: (NSString *) version {
    NSString * path = [[NSString stringWithFormat: @"publickeys/%@/%@",username, version]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ;
    NSURLRequest *request = [self requestWithMethod:@"GET" path: path parameters: nil];
    return request;
}

-(void) getMessageDataForUsername:(NSString *)username andMessageId:(NSInteger)messageId andControlId:(NSInteger) controlId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messageData/%@/%u/%u", username, messageId, controlId]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters: nil];
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock
                                                                                        failure: failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    [operation start];
    
}

-(void) respondToInviteName:(NSString *) friendname action: (NSString *) action successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"invites/%@/%@", friendname, action] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"POST" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];}

-(void) getLatestDataSinceUserControlId: (NSInteger) latestUserControlId spotIds: (NSArray *) spotIds successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    NSMutableDictionary *params = nil;
    if ([spotIds count] > 0) {
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:spotIds options:0 error:nil];
        NSString * jsonString =[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        params = [NSMutableDictionary dictionaryWithObjectsAndKeys:jsonString,@"spotIds", nil];
    }
    DDLogVerbose(@"GetLatestData: params; %@", params);
    
    NSString * path = [NSString stringWithFormat:@"latestdata/%d", latestUserControlId];
    NSURLRequest *request = [self requestWithMethod:@"POST" path:path parameters: params];
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure:failureBlock];
    
    
    
    [operation start];
    
    
}



-(void) logout {
    //send logout
    if (!_loggedOut) {
        DDLogInfo(@"logout");
        NSURLRequest *request = [self requestWithMethod:@"POST" path:@"logout"  parameters:nil];
        AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
        [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            [self deleteCookies];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [self deleteCookies];
        }];
        [operation start];
    }
    
    
}

-(void) deleteCookies {
    //blow cookies away
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:_baseUrl]];
    for (NSHTTPCookie *cookie in cookies)
    {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage]  deleteCookie:cookie];
    }
    
}


-(void) deleteFriend:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"friends/%@", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
    
}


-(void) deleteMessageName:(NSString *) name serverId: (NSInteger) serverid successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messages/%@/%d", name, serverid] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
    
}

-(void) deleteMessagesUTAI:(NSInteger) utaiId name: (NSString *) name successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagesutai/%@/%d", name, utaiId] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
    
}

-(void) userExists: (NSString *) username successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"users/%@/exists", username] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"GET" path: path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) getEarlierMessagesForUsername: (NSString *) username messageId: (NSInteger) messageId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messages/%@/before/%d", username, messageId]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters: nil];
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock
                                                                                        failure: failureBlock];
    
    [operation start];
}

-(void) validateUsername: (NSString *) username password: (NSString *) password signature: (NSString *) signature successBlock:(HTTPSuccessBlock) successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:username,@"username",password,@"password",signature,@"authSig", nil];
    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"validate"  parameters:params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) postFileStreamData: (NSData *) data
                ourVersion: (NSString *) ourVersion
             theirUsername: (NSString *) theirUsername
              theirVersion: (NSString *) theirVersion
                    fileid: (NSString *) fileid
                  mimeType: (NSString *) mimeType
              successBlock:(HTTPSuccessBlock) successBlock
              failureBlock: (HTTPFailureBlock) failureBlock
{
    DDLogInfo(@"postFileStream, fileid: %@", fileid);
    NSString * path = [[NSString stringWithFormat:@"images/%@/%@/%@", ourVersion, theirUsername, theirVersion] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request
    = [self multipartFormRequestWithMethod:@"POST"
                                      path: path
                                parameters:nil
                 constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
                     
                     [formData appendPartWithFileData:data
                                                 name:@"image"
                                             fileName:fileid mimeType:mimeType];
                     
                 }];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    // if you want progress updates as it's uploading, uncomment the following:
    //
    // [operation setUploadProgressBlock:^(NSUInteger bytesWritten,
    // long long totalBytesWritten,
    // long long totalBytesExpectedToWrite) {
    //     NSLog(@"Sent %lld of %lld bytes", totalBytesWritten, totalBytesExpectedToWrite);
    // }];
    
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) postFriendStreamData: (NSData *) data
                  ourVersion: (NSString *) ourVersion
               theirUsername: (NSString *) theirUsername
                          iv: (NSString *) iv
                successBlock:(HTTPSuccessBlock) successBlock
                failureBlock: (HTTPFailureBlock) failureBlock
{
    DDLogInfo(@"postFriendFileStream, iv: %@", iv);
    NSString * path = [[NSString stringWithFormat:@"images/%@/%@", theirUsername, ourVersion] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request
    = [self multipartFormRequestWithMethod:@"POST"
                                      path: path
                                parameters:nil
                 constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
                     
                     [formData appendPartWithFileData:data
                                                 name:@"image"
                                             fileName:iv mimeType:MIME_TYPE_IMAGE];
                     
                 }];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    // if you want progress updates as it's uploading, uncomment the following:
    //
    // [operation setUploadProgressBlock:^(NSUInteger bytesWritten,
    // long long totalBytesWritten,
    // long long totalBytesExpectedToWrite) {
    //     NSLog(@"Sent %lld of %lld bytes", totalBytesWritten, totalBytesExpectedToWrite);
    // }];
    
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) setMessageShareable:(NSString *) name
                   serverId: (NSInteger) serverid
                  shareable: (BOOL) shareable
               successBlock:(HTTPSuccessBlock)successBlock
               failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:(shareable ? @"true" : @"false"),@"shareable", nil];
    NSString * path = [[NSString stringWithFormat:@"messages/%@/%d/shareable", name, serverid] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"PUT" path:path  parameters:params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
    
}

-(void) getKeyTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                  successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock
{
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"keytoken" parameters: params];
    
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];
    
}


-(void) updateKeysForUsername:(NSString *) username
                     password:(NSString *) password
                  publicKeyDH:(NSString *) pkDH
                 publicKeyDSA:(NSString *) pkDSA
                      authSig:(NSString *) authSig
                     tokenSig:(NSString *) tokenSig
                   keyVersion:(NSString *) keyversion
                 successBlock:(HTTPSuccessBlock) successBlock
                 failureBlock:(HTTPFailureBlock) failureBlock
{
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   pkDH, @"dhPub",
                                   pkDSA, @"dsaPub",
                                   authSig, @"authSig",
                                   tokenSig, @"tokenSig",
                                   keyversion, @"keyVersion",
                                   versionString, @"version",
                                   @"ios", @"platform", nil];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }

    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"keys"  parameters:params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];

    
}

-(void) getDeleteTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                  successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"deletetoken" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];

    

    
}

-(void) deleteUsername:(NSString *) username
              password:(NSString *) password
               authSig:(NSString *) authSig
              tokenSig:(NSString *) tokenSig
            keyVersion:(NSString *) keyversion
          successBlock:(HTTPSuccessBlock) successBlock
          failureBlock:(HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   authSig, @"authSig",
                                   tokenSig, @"tokenSig",
                                   keyversion, @"keyVersion",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"/users/delete" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];

    
}


-(void) getPasswordTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                  successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"passwordtoken" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];
    
    
    
    
}

-(void) changePasswordForUsername:(NSString *) username
              oldPassword:(NSString *) password
              newPassword:(NSString *) newPassword
               authSig:(NSString *) authSig
              tokenSig:(NSString *) tokenSig
            keyVersion:(NSString *) keyversion
          successBlock:(HTTPSuccessBlock) successBlock
          failureBlock:(HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   authSig, @"authSig",
                                   tokenSig, @"tokenSig",
                                   keyversion, @"keyVersion",
                                   newPassword, @"newPassword",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"PUT" path:@"users/password" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];
    
}

-(void) deleteFromCache: (NSURLRequest *) request {
    [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
}

@end
