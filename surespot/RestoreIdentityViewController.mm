//
//  RestoreIdentityViewController.m
//  surespot
//
//  Created by Adam on 11/28/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "RestoreIdentityViewController.h"
#import "GTLDrive.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "DDLog.h"
#import "SurespotConstants.h"
#import "IdentityCell.h"
#import "IdentityController.h"
#import "FileController.h"
#import "UIUtils.h"
#import "LoadingView.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

static NSString *const kKeychainItemName = @"Google Drive surespot";
static NSString *const kClientID = @"428168563991-rsb9bkasjio1lbh9s4rd8tmi189gfqv0.apps.googleusercontent.com";
static NSString *const kClientSecret = @"fcqLFxhN1OxonKFIoJG3NcJA";
static NSString* const DRIVE_IDENTITY_FOLDER = @"surespot identity backups";

@interface RestoreIdentityViewController ()
@property (strong, nonatomic) IBOutlet UITableView *tvDrive;
@property (nonatomic, strong) GTLServiceDrive *driveService;
@property (strong) NSMutableArray * driveIdentities;
@property (strong) NSDateFormatter * dateFormatter;
@property (atomic, strong) id progressView;
@end

@implementation RestoreIdentityViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.driveService = [[GTLServiceDrive alloc] init];
    
    _driveIdentities = [NSMutableArray new];
    _driveService.shouldFetchNextPages = YES;
    _driveService.retryEnabled = YES;
    
    [self setAccountFromKeychain];
    
    _bSelect.titleLabel.text = NSLocalizedString(@"select_google_drive_account", nil);
    
    [_tvDrive registerNib:[UINib nibWithNibName:@"IdentityCell" bundle:nil] forCellReuseIdentifier:@"IdentityCell"];
    
    _dateFormatter = [[NSDateFormatter alloc]init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
}

-(void) setAccountFromKeychain {
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:kClientID
                                                                                     clientSecret:kClientSecret];
    
    
    
    if (_driveService.authorizer && [_driveService.authorizer isMemberOfClass:[GTMOAuth2Authentication class]]) {
        
        
        
        NSString * currentEmail = [[((GTMOAuth2Authentication *) _driveService.authorizer ) parameters] objectForKey:@"email"];
        if (currentEmail) {
            _accountLabel.text = currentEmail;
            [self loadIdentities];
            return;
        }
    }

    _accountLabel.text = NSLocalizedString(@"no_google_account_selected", nil);
    [_driveIdentities removeAllObjects];
    [_tvDrive reloadData];

    
}

// Helper to check if user is authorized
- (BOOL)isAuthorized
{
    return [((GTMOAuth2Authentication *)self.driveService.authorizer) canAuthorize];
}

// Creates the auth controller for authorizing access to Google Drive.
- (GTMOAuth2ViewControllerTouch *)createAuthController
{
    GTMOAuth2ViewControllerTouch *authController;
    authController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeDriveFile
                                                                clientID:kClientID
                                                            clientSecret:kClientSecret
                                                        keychainItemName:kKeychainItemName
                                                                delegate:self
                                                        finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    return authController;
}

// Handle completion of the authorization process, and updates the Drive service
// with the new credentials.
- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)authResult
                 error:(NSError *)error
{
    if (error != nil)
    {
        if ([error code] != kGTMOAuth2ErrorWindowClosed) {
            [UIUtils showToastKey:error.localizedDescription];
        }
        [self setAccountFromKeychain];
    }
    else
    {
        if (authResult) {
            self.driveService.authorizer = authResult;
            [self loadIdentities];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)bLoadIdentities:(id)sender {
    if ([self isAuthorized]) {
        _driveService.authorizer = nil;
    }
    
    [self loadIdentities];
    
}

-(void) loadIdentities {
    if (![self isAuthorized])
    {
        // Not yet authorized, request authorization and push the login UI onto the navigation stack.
        DDLogInfo(@"launching google authorization");
        [self.navigationController pushViewController:[self createAuthController] animated:YES];
        return;
    }
    
    [self retrieveIdentityFilesCompletionBlock:^(id identityFiles) {
        [_driveIdentities removeAllObjects];
        [_driveIdentities addObjectsFromArray:identityFiles];
        [_tvDrive reloadData];
    }];
    
}

-(void) ensureDriveIdentityDirectoryCompletionBlock: (CallbackBlock) completionBlock {
    
    GTLQueryDrive *queryFilesList = [GTLQueryDrive queryForChildrenListWithFolderId:@"root"];
    queryFilesList.q =  [NSString stringWithFormat:@"title='%@' and trashed = false and mimeType='application/vnd.google-apps.folder'", DRIVE_IDENTITY_FOLDER];
    // queryTicket can be used to track the status of the request.
    GTLServiceTicket *queryTicket =
    [_driveService executeQuery:queryFilesList
              completionHandler:^(GTLServiceTicket *ticket, GTLDriveFileList *files,
                                  NSError *error) {
                  if (error == nil) {
                      if (files.items.count > 0) {
                          NSString * identityDirId = nil;
                          
                          for (id file in files.items) {
                              identityDirId = [file identifier];
                              if (identityDirId) break;
                          }
                          completionBlock(identityDirId);
                          return;
                      }
                      else {
                          GTLDriveFile *folderObj = [GTLDriveFile object];
                          folderObj.title = DRIVE_IDENTITY_FOLDER;
                          folderObj.mimeType = @"application/vnd.google-apps.folder";
                          
                          // To create a folder in a specific parent folder, specify the identifier
                          // of the parent:
                          // _resourceId is the identifier from the parent folder
                          
                          GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
                          parentRef.identifier = @"root";
                          folderObj.parents = [NSArray arrayWithObject:parentRef];
                          
                          
                          GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:folderObj uploadParameters:nil];
                          
                          [_driveService executeQuery:query
                                    completionHandler:^(GTLServiceTicket *ticket, GTLDriveFile *file,
                                                        NSError *error) {
                                        NSString * identityDirId = nil;
                                        if (error == nil) {
                                            
                                            if (file) {
                                                identityDirId = [file identifier];
                                            }
                                            
                                        } else {
                                            DDLogError(@"An error occurred: %@", error);
                                            
                                        }
                                        completionBlock(identityDirId);
                                        return;
                                        
                                    }];
                          
                          
                      }
                      
                      
                  } else {
                      DDLogError(@"An error occurred: %@", error);
                      completionBlock(nil);
                  }
              }];
    
}

- (void)retrieveIdentityFilesCompletionBlock:(CallbackBlock) callback {
    _progressView = [LoadingView loadingViewInView:self.view keyboardHeight:0 textKey:@"progress_loading_identities"];
    
    [self ensureDriveIdentityDirectoryCompletionBlock:^(NSString * identityDirId) {
        DDLogInfo(@"got identity folder id %@", identityDirId);
        
        if (identityDirId) {
            GTLQueryDrive *queryFilesList = [GTLQueryDrive queryForChildrenListWithFolderId:identityDirId];
            queryFilesList.q = @"trashed = false";
            
            [_driveService executeQuery:queryFilesList
                      completionHandler:^(GTLServiceTicket *ticket, GTLDriveFileList *files,
                                          NSError *error) {
                          
                          if (error == nil) {
                              DDLogInfo(@"retrieved Identity files %@", files.items);
                              NSMutableArray * identityFiles = [NSMutableArray new];
                              NSInteger dlCount = [[files items] count];
                              
                              //todo do this in a queue
                              NSObject * completionLock = [NSObject new];
                              __block NSInteger completed = 0;
                              
                              
                              for (GTLDriveChildReference *child in files) {
                                  
                                  GTLQuery *query = [GTLQueryDrive queryForFilesGetWithFileId:child.identifier];
                                  
                                  // queryTicket can be used to track the status of the request.
                                  [self.driveService executeQuery:query
                                                completionHandler:^(GTLServiceTicket *ticket,
                                                                    GTLDriveFile *file,
                                                                    NSError *error) {
                                                    
                                                    if (!error) {
                                                        DDLogInfo(@"\nfile name = %@", file.originalFilename);
                                                        NSMutableDictionary * identityFile = [NSMutableDictionary new];
                                                        [identityFile  setObject: [[IdentityController sharedInstance] identityNameFromFile: file.originalFilename] forKey:@"name"];
                                                        [identityFile setObject:file.modifiedDate forKey:@"date"];
                                                        [identityFile setObject:file.downloadUrl forKey:@"url"];
                                                        
                                                        [identityFiles addObject:identityFile];
                                                    }
                                                    else {
                                                        DDLogError(@"An error occurred: %@", error);
                                                    }
                                                    
                                                    @synchronized (completionLock) {
                                                        completed++;
                                                    }
                                                    if (completed == dlCount) {
                                                        DDLogInfo(@"file data download complete, files: %@", identityFiles);
                                                        callback(identityFiles);
                                                        [_progressView removeView];
                                                    }
                                                    
                                                    
                                                }];
                              }
                              
                          } else {
                              DDLogError(@"An error occurred: %@", error);
                              [_progressView removeView];
                          }
                          
                          
                          
                      }];
            
        }
        else {//couldn't get identity dir id
            [_progressView removeView];
        }
        
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _driveIdentities.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"IdentityCell";
    
    IdentityCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSDictionary *file = [self.driveIdentities objectAtIndex:indexPath.row];
    cell.nameLabel.text = [file objectForKey:@"name"];
    cell.dateLabel.text = [_dateFormatter stringFromDate: [[file objectForKey:@"date"] date]];
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //todo limit identities to 3
    
    
    NSDictionary * rowData = [_driveIdentities objectAtIndex:indexPath.row];
    NSString * name = [rowData objectForKey:@"name"];
    NSString * url = [rowData objectForKey:@"url"];
    
    //todo get password
    NSString * password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:name];
    if (!password) {
    }
    
    GTMHTTPFetcher *fetcher =
    [self.driveService.fetcherService fetcherWithURLString:url];
    
    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
        //  [alert dismissWithClickedButtonIndex:0 animated:YES];
        if (error == nil) {
            NSData * identityData = [FileController gunzipIfNecessary:data];
            [[IdentityController sharedInstance] importIdentityData:identityData username:name password:@"a" callback:^(id result) {
                if (result) {
                    [UIUtils showToastMessage:result duration:2];
                }
            }];
        } else {
            DDLogError(@"An error occurred: %@", error);
        }
    }];
    
}

@end
