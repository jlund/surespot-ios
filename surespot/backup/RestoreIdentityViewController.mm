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
static NSString* const DRIVE_IDENTITY_FOLDER = @"surespot identity backups";

@interface RestoreIdentityViewController ()
@property (strong, nonatomic) IBOutlet UITableView *tvDrive;
@property (nonatomic, strong) GTLServiceDrive *driveService;
@property (strong) NSMutableArray * driveIdentities;
@property (strong) NSDateFormatter * dateFormatter;
@property (atomic, strong) id progressView;
@property (atomic, strong) NSString * name;
@property (atomic, strong) NSString * url;
@property (atomic, strong) NSString * storedPassword;
- (IBAction)bLoadIdentities:(id)sender;
@property (strong, nonatomic) IBOutlet UIButton *bSelect;
@property (strong, nonatomic) IBOutlet UILabel *accountLabel;
@property (strong, nonatomic) IBOutlet UILabel *labelGoogleDriveBackup;

@end

@implementation RestoreIdentityViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationController.navigationBar.translucent = NO;
    [self.navigationItem setTitle:NSLocalizedString(@"restore", nil)];
    
	self.driveService = [[GTLServiceDrive alloc] init];
    
    _driveIdentities = [NSMutableArray new];
    _driveService.shouldFetchNextPages = YES;
    _driveService.retryEnabled = YES;
    
    [self setAccountFromKeychain];
    [self loadIdentitiesAuthIfNecessary:NO];
    
    [_tvDrive registerNib:[UINib nibWithNibName:@"IdentityCell" bundle:nil] forCellReuseIdentifier:@"IdentityCell"];
    
    _dateFormatter = [[NSDateFormatter alloc]init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    _labelGoogleDriveBackup.text = NSLocalizedString(@"restore_drive", nil);
}

-(void) setAccountFromKeychain {
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:GOOGLE_DRIVE_CLIENT_ID
                                                                                     clientSecret:GOOGLE_DRIVE_CLIENT_SECRET];
    [self updateUI];
}

-(void) updateUI {
    if (_driveService.authorizer && [_driveService.authorizer isMemberOfClass:[GTMOAuth2Authentication class]]) {
        NSString * currentEmail = [[((GTMOAuth2Authentication *) _driveService.authorizer ) parameters] objectForKey:@"email"];
        if (currentEmail) {
            _accountLabel.text = currentEmail;
            [_bSelect setTitle:@"remove" forState:UIControlStateNormal];
            return;
            
        }
    }
    
    _accountLabel.text = NSLocalizedString(@"no_google_account_selected", nil);
    [_bSelect setTitle:NSLocalizedString(@"select", nil) forState:UIControlStateNormal];
    
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
    //http://stackoverflow.com/questions/13693617/error-500-when-performing-a-query-with-drive-file-scope
    authController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope: [[kGTLAuthScopeDriveFile stringByAppendingString:@" "] stringByAppendingString: kGTLAuthScopeDriveMetadataReadonly]
                                                                clientID:GOOGLE_PLUS_CLIENT_ID
                                                            clientSecret:GOOGLE_DRIVE_CLIENT_SECRET
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
            [self updateUI];
            [self loadIdentitiesAuthIfNecessary:NO];
            
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
        [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
        _driveService.authorizer = nil;
        [self updateUI];
    }
    else {
        [self loadIdentitiesAuthIfNecessary:YES];
    }
}

-(void) loadIdentitiesAuthIfNecessary: (BOOL) auth {
    if (![self isAuthorized])
    {
        if (auth) {
            // Not yet authorized, request authorization and push the login UI onto the navigation stack.
            DDLogInfo(@"launching google authorization");
            [self.navigationController pushViewController:[self createAuthController] animated:YES];
        }
        return;
    }
    
    [self retrieveIdentityFilesCompletionBlock:^(id identityFiles) {
        [_driveIdentities removeAllObjects];
        [_driveIdentities addObjectsFromArray:[identityFiles sortedArrayUsingComparator:^(id obj1, id obj2) {
            NSDate *d1 = [obj1 objectForKey:@"date"];
            NSDate *d2 = [obj2 objectForKey:@"date"];
            return [d2 compare:d1];
        }]];
        [_tvDrive reloadData];
    }];
    
}

-(void) ensureDriveIdentityDirectoryCompletionBlock: (CallbackBlock) completionBlock {
    
    GTLQueryDrive *queryFilesList = [GTLQueryDrive queryForChildrenListWithFolderId:@"root"];
    queryFilesList.q =  [NSString stringWithFormat:@"title='%@' and trashed = false and mimeType='application/vnd.google-apps.folder'", DRIVE_IDENTITY_FOLDER];
    
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
    _progressView = [LoadingView showViewKey:@"progress_loading_identities"];
    
    [self ensureDriveIdentityDirectoryCompletionBlock:^(NSString * identityDirId) {
        DDLogInfo(@"got identity folder id %@", identityDirId);
        
        if (!identityDirId) {
            [UIUtils showToastKey:@"could_not_list_identities_from_google_drive" duration:2];
            [_progressView removeView];
            callback(nil);
            return;
            
        }
        GTLQueryDrive *queryFilesList = [GTLQueryDrive queryForChildrenListWithFolderId:identityDirId];
        queryFilesList.q = @"trashed = false";
        
        [_driveService executeQuery:queryFilesList
                  completionHandler:^(GTLServiceTicket *ticket, GTLDriveFileList *files,
                                      NSError *error) {
                      
                      if (error) {
                          DDLogError(@"An error occurred: %@", error);
                          [UIUtils showToastKey:@"could_not_list_identities_from_google_drive" duration:2];
                          [_progressView removeView];
                          
                          callback(nil);
                          return;
                      }
                      
                      DDLogInfo(@"retrieved Identity files %@", files.items);
                      NSInteger dlCount = [[files items] count];
                      if (dlCount == 0) {
                          //no identities to download
                          [_progressView removeView];
                          callback(nil);
                          return;
                      }
                      
                      NSMutableArray * identityFiles = [NSMutableArray new];
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
                                                [identityFile setObject:[file.modifiedDate date] forKey:@"date"];
                                                [identityFile setObject:file.downloadUrl forKey:@"url"];
                                                [identityFiles addObject:identityFile];
                                            }
                                            else {
                                                DDLogError(@"An error occurred: %@", error);
                                            }
                                            
                                            @synchronized (completionLock) {
                                                completed++;
                                                
                                                if (completed == dlCount) {
                                                    DDLogInfo(@"file data download complete, files: %@", identityFiles);
                                                    
                                                    [_progressView removeView];
                                                    callback(identityFiles);
                                                }
                                            }
                                            
                                            
                                        }];
                      }
                      
                  }];
        
        
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
    cell.dateLabel.text = [_dateFormatter stringFromDate: [file objectForKey:@"date"]];
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
    bgColorView.layer.masksToBounds = YES;
    cell.selectedBackgroundView = bgColorView;
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //todo limit identities to 3
    NSDictionary * rowData = [_driveIdentities objectAtIndex:indexPath.row];
    NSString * name = [rowData objectForKey:@"name"];
    NSString * url = [rowData objectForKey:@"url"];
    
    _storedPassword = [[IdentityController sharedInstance] getStoredPasswordForIdentity:name];
    _name = name;
    _url = url;
    
    //if (!_password) {
    
    //show alert view to get password
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"restore_identity", nil), name] message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name] delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil) otherButtonTitles:NSLocalizedString(@"ok", nil), nil];
    alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
    [alertView show];
    
    //    }
    //    else {
    //        //show alert view to confirm
    //        //todo localization
    //        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"are you sure" message:@"are you sure you want to import this identity" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Ok", nil];
    //        [alertView show];
    //    }
}

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSString * password = nil;
        if (alertView.alertViewStyle == UIAlertViewStyleSecureTextInput) {
            password = [[alertView textFieldAtIndex:0] text];
        }
        
        if (![UIUtils stringIsNilOrEmpty:password]) {
            [self importIdentity:_name url:_url password:password];
        }
    }
}

-(void) importIdentity: (NSString *) name url: (NSString *) url password: (NSString *) password {
    _progressView = [LoadingView showViewKey:@"progress_restoring_identity"];
    
    GTMHTTPFetcher *fetcher =
    [self.driveService.fetcherService fetcherWithURLString:url];
    
    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
        if (error == nil) {
            NSData * identityData = [FileController gunzipIfNecessary:data];
            [[IdentityController sharedInstance] importIdentityData:identityData username:name password:password callback:^(id result) {
                if (result) {
                    [UIUtils showToastMessage:result duration:2];
                }
                else {
                    [UIUtils showToastKey:@"identity_imported_successfully" duration:2];
                }
                
                //update stored password
                if (![UIUtils stringIsNilOrEmpty:_storedPassword] && ![_storedPassword isEqualToString:password]) {
                    [[IdentityController sharedInstance] storePasswordForIdentity:name password:password];
                }
                
                _storedPassword = nil;
                [_progressView removeView];
                
                //if we now only have 1 identity, go to login view controller
                if ([[[IdentityController sharedInstance] getIdentityNames] count] == 1) {
                    [self.navigationController popToRootViewControllerAnimated:YES];
                }
            }];
        } else {
            DDLogError(@"An error occurred: %@", error);
            [UIUtils showToastKey:@"could_not_list_identities_from_google_drive" duration:2];
            _storedPassword = nil;
            [_progressView removeView];
        }
    }];
    
}

@end
