//
//  BackupIdentityViewController.m
//  surespot
//
//  Created by Adam on 11/28/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "BackupIdentityViewController.h"
#import "IdentityController.h"
#import "DDLog.h"
#import "SurespotConstants.h"
#import "UIUtils.h"
#import "LoadingView.h"
#import "GTLDrive.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "FileController.h"
#import "NSData+Gunzip.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface BackupIdentityViewController ()
@property (strong, nonatomic) IBOutlet UILabel *labelGoogleDriveBackup;
@property (strong, nonatomic) IBOutlet UIButton *bSelect;
@property (strong, nonatomic) IBOutlet UILabel *accountLabel;
@property (atomic, strong) NSArray * identityNames;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;
@property (strong, nonatomic) IBOutlet UIButton *bExecute;

@property (nonatomic, strong) GTLServiceDrive *driveService;
@property (atomic, strong) id progressView;
@property (atomic, strong) NSString * name;
@property (atomic, strong) NSString * url;
@end


static NSString *const kKeychainItemName = @"Google Drive surespot";
static NSString *const kClientID = @"428168563991-rsb9bkasjio1lbh9s4rd8tmi189gfqv0.apps.googleusercontent.com";
static NSString *const kClientSecret = @"fcqLFxhN1OxonKFIoJG3NcJA";
static NSString* const DRIVE_IDENTITY_FOLDER = @"surespot identity backups";


@implementation BackupIdentityViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"backup", nil)];
    [_bExecute setTitle:NSLocalizedString(@"backup_drive_button", nil) forState:UIControlStateNormal];
    [self loadIdentityNames];
    self.navigationController.navigationBar.translucent = NO;
    
    self.driveService = [[GTLServiceDrive alloc] init];
    _driveService.shouldFetchNextPages = YES;
    _driveService.retryEnabled = YES;
    
    [self setAccountFromKeychain];
    
    _labelGoogleDriveBackup.text = NSLocalizedString(@"backup_drive", nil);
    
    
}

-(void) loadIdentityNames {
    _identityNames = [[IdentityController sharedInstance] getIdentityNames];
}



// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [_identityNames count];
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    //set item per row
    return [_identityNames objectAtIndex:row];
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void) setAccountFromKeychain {
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:kClientID
                                                                                     clientSecret:kClientSecret];
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
            [self updateUI];
            
        }
    }
}


- (IBAction)select:(id)sender {
    if ([self isAuthorized]) {
        [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
        _driveService.authorizer = nil;
        [self updateUI];
    }
    else {
        [self selectAccount];
    }
}

-(void) selectAccount {
    if (![self isAuthorized])
    {
        
        // Not yet authorized, request authorization and push the login UI onto the navigation stack.
        DDLogInfo(@"launching google authorization");
        [self.navigationController pushViewController:[self createAuthController] animated:YES];
        
    }
    
    
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



- (IBAction)execute:(id)sender {
    NSString * name = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    _name = name;
    
    //show alert view to get password
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"backup_identity", nil), name] message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name] delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil) otherButtonTitles:NSLocalizedString(@"ok", nil), nil];
    alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
    [alertView show];
    
}

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSString * password = nil;
        if (alertView.alertViewStyle == UIAlertViewStyleSecureTextInput) {
            password = [[alertView textFieldAtIndex:0] text];
        }
        
        if (![UIUtils stringIsNilOrEmpty:password]) {
            [self backupIdentity:_name password:password];
        }
    }
}

-(void) getIdentityFile: (NSString *) identityDirId name: (NSString *) name callback: (CallbackBlock) callback {
    GTLQueryDrive *queryFilesList = [GTLQueryDrive queryForChildrenListWithFolderId:identityDirId];
    queryFilesList.q = [NSString stringWithFormat:@"title = '%@' and trashed = false", [name stringByAppendingPathExtension: IDENTITY_EXTENSION]];
    
    [_driveService executeQuery:queryFilesList
              completionHandler:^(GTLServiceTicket *ticket, GTLDriveFileList *files,
                                  NSError *error) {
                  
                  if (error) {
                      DDLogError(@"An error occurred: %@", error);
                      callback(nil);
                      return;
                  }
                  
                  DDLogInfo(@"retrieved identity files %@", files.items);
                  NSInteger dlCount = [[files items] count];
                  
                  if (dlCount == 1) {
                      callback([files.items objectAtIndex:0]);
                      return;
                  }
                  else {
                      if (dlCount > 1) {
                          //delete all but one - shouldn't happen but just in case
                          for (int i=dlCount;i>1;i--) {
                              GTLQueryDrive *query = [GTLQueryDrive queryForFilesDeleteWithFileId:[[files.items objectAtIndex:i-1] identifier]];
                              [_driveService executeQuery:query
                                        completionHandler:^(GTLServiceTicket *ticket, id object,
                                                            NSError *error) {
                                            if (error != nil) {
                                                DDLogError(@"An error occurred: %@", error);
                                            }
                                        }];
                          }
                          
                          callback([files.items objectAtIndex:0]);
                          return;
                      }
                  }
                  
                  callback(nil);
              }];
}

-(void) backupIdentity: (NSString *) name password: (NSString *) password {
    _progressView = [LoadingView loadingViewInView:self.view keyboardHeight:0 textKey:@"progress_backup_identity_drive"];
    
    [self ensureDriveIdentityDirectoryCompletionBlock:^(NSString * identityDirId) {
        if (!identityDirId) {
            [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
            return;
        }
        
        DDLogInfo(@"got identity folder id %@", identityDirId);
        
        [[IdentityController sharedInstance] exportIdentityDataForUsername:name password:password callback:^(NSString *error, id identityData) {
            if (error) {
                [UIUtils showToastMessage:error duration:2];
                [_progressView removeView];
                return;
            }
            else {
                if (!identityData) {
                    [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
                    [_progressView removeView];
                    return;
                }
                
                [self getIdentityFile:identityDirId name:name callback:^(GTLDriveFile * idFile) {
                    if (idFile) {
                        GTLUploadParameters *uploadParameters = [GTLUploadParameters
                                                                 uploadParametersWithData:[identityData gzipDeflate]
                                                                 MIMEType:@"application/octet-stream"];
                        
                        GTLQueryDrive *query = [GTLQueryDrive queryForFilesUpdateWithObject:idFile fileId:idFile.identifier uploadParameters:uploadParameters];
                        
                        [self.driveService executeQuery:query
                                      completionHandler:^(GTLServiceTicket *ticket,
                                                          GTLDriveFile *updatedFile,
                                                          NSError *error) {
                                          if (error == nil) {
                                              [UIUtils showToastKey:@"identity_successfully_backed_up_to_google_drive"];
                                          } else {
                                              [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive"];
                                          }
                                          [_progressView removeView];
                                      }];
                        
                        
                    }
                    else {
                        GTLDriveFile *driveFile = [[GTLDriveFile alloc]init] ;
                        GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
                        parentRef.identifier = identityDirId;
                        driveFile.parents = @[parentRef];
                        
                        driveFile.mimeType = @"application/octet-stream";
                        NSString * filename = [name stringByAppendingPathExtension: IDENTITY_EXTENSION];
                        driveFile.originalFilename = filename;
                        driveFile.title = filename;
                        
                        GTLUploadParameters *uploadParameters = [GTLUploadParameters
                                                                 uploadParametersWithData:[identityData gzipDeflate]
                                                                 MIMEType:@"application/octet-stream"];
                        
                        GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:driveFile
                                                                           uploadParameters:uploadParameters];
                        
                        [self.driveService executeQuery:query
                                      completionHandler:^(GTLServiceTicket *ticket,
                                                          GTLDriveFile *updatedFile,
                                                          NSError *error) {
                                          if (error == nil) {
                                              [UIUtils showToastKey:@"identity_successfully_backed_up_to_google_drive"];
                                          } else {
                                              [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive"];
                                          }
                                          [_progressView removeView];
                                      }];
                        
                    }
                }];
                
            }
            
            
        }];
    }];
}



@end
