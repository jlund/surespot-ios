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

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

NSString *const baseUrl = @"http://192.168.10.68:8080";
// @"https://server.surespot.me:443"

@implementation NetworkController

+(NetworkController*)sharedInstance
{
    static NetworkController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] initWithBaseURL:[NSURL URLWithString:baseUrl]];
    });
    
    return sharedInstance;
}

-(NetworkController*)init
{
    //call super init
    self = [super init];
    
    if (self != nil) {
        
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        [self registerHTTPOperationClass:[AFHTTPRequestOperation class]];
        
        
        
        // Accept HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
        [self setDefaultHeader:@"Accept-Charset" value:@"utf-8"];
        //[self setDefaultHeader:@"Accept" value:@"application/json"];
        
        self.parameterEncoding = AFJSONParameterEncoding;
    }
    
    return self;
}

-(void) loginWithUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
             successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock
{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:username,@"username",password,@"password",signature, @"authSig", nil];
    
    //add apnTeken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"login" parameters: params];
    
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        
        //save the cookie
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:baseUrl]];
        
        NSHTTPCookie * surespotCookie;
        for (NSHTTPCookie *cookie in cookies)
        {
            if ([cookie.name isEqualToString:@"connect.sid"]) {
                surespotCookie = cookie;
            }
        }
        
        successBlock(request, response, JSON);
        
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        failureBlock(request, response, error, JSON);
    } ];
    
    
    [operation start];
    
}

-(void) addUser: (NSString *) username derivedPassword:  (NSString *)derivedPassword dhKey: (NSString *)encodedDHKey dsaKey: (NSString *)encodedDSAKey signature: (NSString *)signature version: (NSString *) version successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:username,@"username",derivedPassword,@"password",signature, @"authSig", encodedDHKey, @"dhPub", encodedDSAKey, @"dsaPub", version, @"version", nil];
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"users" parameters: params];
    
    
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    
    [operation start];
}

-(void) getFriendsSuccessBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"friends" parameters:nil];
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock
                                                                                        failure: failureBlock];
    operation.JSONReadingOptions = NSJSONReadingMutableContainers;
    [operation start];
}

-(void) inviteFriend: (NSString *) friendname successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSURLRequest *request = [self requestWithMethod:@"POST" path:[@"invite/" stringByAppendingString:friendname]  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

- (void) getKeyVersionForUsername:(NSString *)username successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock
{
    NSURLRequest *request = [self requestWithMethod:@"GET" path:[@"keyversion/"  stringByAppendingString:username] parameters: nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

- (void) getPublicKeysForUsername:(NSString *)username andVersion:(NSString *)version successBlock:(JSONSuccessBlock)successBlock failureBlock:(JSONFailureBlock) failureBlock{
    
    //todo use formatter
    NSURLRequest *request = [self requestWithMethod:@"GET" path: [NSString stringWithFormat: @"publickeys/%@/%@",username, version] parameters: nil];
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure: failureBlock];
    
    //dont't need this on main thread
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    [operation start];
}

-(void) getMessageDataForUsername:(NSString *)username andMessageId:(NSInteger)messageId andControlId:(NSInteger) controlId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    
    NSString * path = [NSString stringWithFormat:@"messageData/%@/%u/%u", username, messageId, controlId];
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters: nil];
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock
                                                                                        failure: failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    [operation start];
    
}

-(void) respondToInviteName:(NSString *) friendname action: (NSString *) action successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [NSString stringWithFormat:@"invites/%@/%@", friendname, action];
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
    DDLogInfo(@"GetLatestData: params; %@", params);
    
    NSString * path = [NSString stringWithFormat:@"latestdata/%d", latestUserControlId];
    NSURLRequest *request = [self requestWithMethod:@"POST" path:path parameters: params];
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure:failureBlock];
    
    
    
    [operation start];
    
    
}



-(void) logout {
    //send logout
    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"logout"  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self deleteCookies];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self deleteCookies];
    }];
    [operation start];
    
    
}

-(void) deleteCookies {
    //blow cookies away
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:baseUrl]];
    for (NSHTTPCookie *cookie in cookies)
    {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage]  deleteCookie:cookie];
    }
    
}


-(void) deleteFriend:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [NSString stringWithFormat:@"friends/%@", friendname];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];

}


-(void) deleteMessageName:(NSString *) name serverId: (NSInteger) serverid successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [NSString stringWithFormat:@"messages/%@/%ld", name, (long)serverid];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
    
}
@end
