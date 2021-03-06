//
//  NetworkController.h
//  surespot
//
//  Created by Adam on 6/16/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "AFHTTPClient.h"
#import "AFNetworking.h"
#import "SurespotConstants.h"

typedef void (^JSONResponseBlock) (NSDictionary* json);
typedef void (^JSONSuccessBlock) (NSURLRequest *request, NSHTTPURLResponse *response, id JSON);
typedef void (^JSONFailureBlock) (NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON);
typedef void (^HTTPSuccessBlock) (AFHTTPRequestOperation *operation , id responseObject);
typedef void (^HTTPFailureBlock) (AFHTTPRequestOperation *operation , NSError *error );


@interface NetworkController : AFHTTPClient

+(NetworkController*)sharedInstance;

-(void) loginWithUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature              successBlock:(JSONSuccessBlock) successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) addUser: (NSString *) username derivedPassword:  (NSString *)derivedPassword dhKey: (NSString *)encodedDHKey dsaKey: (NSString *)encodedDSAKey signature: (NSString *)signature successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) getFriendsSuccessBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) inviteFriend: (NSString *) friendname successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock ;
-(void) getKeyVersionForUsername:(NSString *)username successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) getPublicKeysForUsername:(NSString *)username andVersion:(NSString *)version successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) getMessageDataForUsername:(NSString *)username andMessageId:(NSInteger)messageId andControlId:(NSInteger) controlId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) respondToInviteName:(NSString *) friendname action: (NSString *) action successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) getLatestDataSinceUserControlId: (NSInteger) latestUserControlId spotIds: (NSArray *) spotIds successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) logout;
-(void) deleteFriend:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) deleteMessageName:(NSString *) name serverId: (NSInteger) serverid successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) deleteMessagesUTAI:(NSInteger) utaiId name: (NSString *) name successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) userExists: (NSString *) username successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) setUnauthorized;
-(void) getEarlierMessagesForUsername: (NSString *) username messageId: (NSInteger) messageId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) validateUsername: (NSString *) username password: (NSString *) password signature: (NSString *) signature successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) postFileStreamData: (NSData *) data
                ourVersion: (NSString *) ourVersion
             theirUsername: (NSString *) theirUsername
              theirVersion: (NSString *) theirVersion
                    fileid: (NSString *) fileid
                  mimeType: (NSString *) mimeType
              successBlock:(JSONSuccessBlock) successBlock
              failureBlock: (JSONFailureBlock) failureBlock;

-(void) setMessageShareable:(NSString *) name
                   serverId: (NSInteger) serverid
                  shareable: (BOOL) shareable
               successBlock:(HTTPSuccessBlock)successBlock
               failureBlock: (HTTPFailureBlock) failureBlock;

-(void) postFriendStreamData: (NSData *) data
                  ourVersion: (NSString *) ourVersion
               theirUsername: (NSString *) theirUsername
                          iv: (NSString *) iv
                successBlock:(HTTPSuccessBlock) successBlock
                failureBlock: (HTTPFailureBlock) failureBlock;

-(void) getKeyTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                  successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;

-(void) updateKeysForUsername:(NSString *) username
                     password:(NSString *) password
                  publicKeyDH:(NSString *) pkDH
                 publicKeyDSA:(NSString *) pkDSA
                      authSig:(NSString *) authSig
                     tokenSig:(NSString *) tokenSig
                   keyVersion:(NSString *) keyversion
                 successBlock:(HTTPSuccessBlock) successBlock
                 failureBlock:(HTTPFailureBlock) failureBlock;

-(void) getDeleteTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                  successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;

-(void) deleteUsername:(NSString *) username
              password:(NSString *) password
               authSig:(NSString *) authSig
              tokenSig:(NSString *) tokenSig
            keyVersion:(NSString *) keyversion
          successBlock:(HTTPSuccessBlock) successBlock
          failureBlock:(HTTPFailureBlock) failureBlock;

-(void) getPasswordTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                    successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;

-(void) changePasswordForUsername:(NSString *) username
                         oldPassword:(NSString *) password
                         newPassword:(NSString *) newPassword
                          authSig:(NSString *) authSig
                         tokenSig:(NSString *) tokenSig
                       keyVersion:(NSString *) keyversion
                     successBlock:(HTTPSuccessBlock) successBlock
                     failureBlock:(HTTPFailureBlock) failureBlock;

-(void) deleteFromCache: (NSURLRequest *) request;
-(NSURLRequest *) buildPublicKeyRequestForUsername: (NSString *) username version: (NSString *) version;

-(void) getShortUrl:(NSString*) longUrl callback: (CallbackBlock) callback;

-(void) uploadReceipt: (NSString *) receipt
                successBlock:(HTTPSuccessBlock) successBlock
                failureBlock: (HTTPFailureBlock) failureBlock;

@end
