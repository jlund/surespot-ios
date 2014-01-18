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
#import "NSString+Sensitivize.h"
#import "BackupHelpViewController.h"

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
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (atomic, strong) NSString * url;
@property (nonatomic, strong) UIPopoverController * popover;
@end


static NSString *const kKeychainItemName = @"Google Drive surespot";
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
    _scrollView.contentSize = self.view.frame.size;
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"help",nil) style:UIBarButtonItemStylePlain target:self action:@selector(showHelp)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    [_userPicker selectRow:[_identityNames indexOfObject:[[IdentityController sharedInstance] getLoggedInUser]] inComponent:0 animated:YES];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.popover = nil;
}

-(void) showHelp {
    BackupHelpViewController * controller = [[BackupHelpViewController alloc] initWithNibName:@"BackupHelpView" bundle:nil];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:controller];
        _popover.delegate = self;
        CGFloat x = self.view.bounds.size.width;
        CGFloat y =self.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        [_popover setPopoverContentSize:CGSizeMake(320, 480) animated:NO];
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
        
    } else {
        [self.navigationController pushViewController:controller animated:YES];
    }
    
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromOrientation
{
    
    // if the popover is showing, adjust its position after the re-orientation by presenting it again:
    if (self.popover != nil)
    {
        CGFloat x =self.view.bounds.size.width;
        CGFloat y =self.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        
        [self.popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
    }
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
                                                                                         clientID:GOOGLE_CLIENT_ID
                                                                                     clientSecret:GOOGLE_CLIENT_SECRET];
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
    //http://stackoverflow.com/questions/13693617/error-500-when-performing-a-query-with-drive-file-scope
    authController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope:[[kGTLAuthScopeDriveFile stringByAppendingString:@" "] stringByAppendingString: kGTLAuthScopeDriveMetadataReadonly]
                      
                                                                clientID:GOOGLE_CLIENT_ID
                                                            clientSecret:GOOGLE_CLIENT_SECRET
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
            [UIUtils showToastMessage:error.localizedDescription duration:2];
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
    if ([self isAuthorized]) {
        NSString * name = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
        _name = name;
        
        //show alert view to get password
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"backup_identity", nil), name] message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name] delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil) otherButtonTitles:NSLocalizedString(@"ok", nil), nil];
        alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
        [alertView show];
    }
    
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
    queryFilesList.q = [NSString stringWithFormat:@"title = '%@' and trashed = false", [[name  caseInsensitivize] stringByAppendingPathExtension: IDENTITY_EXTENSION]];
    
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
    _progressView = [LoadingView showViewKey:@"progress_backup_identity_drive"];
    
    [self ensureDriveIdentityDirectoryCompletionBlock:^(NSString * identityDirId) {
        if (!identityDirId) {
            [_progressView removeView];
            _progressView = nil;
            
            [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
            return;
        }
        
        DDLogInfo(@"got identity folder id %@", identityDirId);
        
        [[IdentityController sharedInstance] exportIdentityDataForUsername:name password:password callback:^(NSString *error, id identityData) {
            if (error) {
                [_progressView removeView];
                _progressView = nil;
                
                [UIUtils showToastMessage:error duration:2];
                return;
            }
            else {
                if (!identityData) {
                    [_progressView removeView];
                    _progressView = nil;
                    
                    [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
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
                                          [_progressView removeView];
                                          _progressView = nil;
                                          
                                          if (error == nil) {
                                              [UIUtils showToastKey:@"identity_successfully_backed_up_to_google_drive" duration:2];
                                          } else {
                                              [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
                                          }
                                      }];
                        
                        
                    }
                    else {
                        GTLDriveFile *driveFile = [[GTLDriveFile alloc]init] ;
                        GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
                        parentRef.identifier = identityDirId;
                        driveFile.parents = @[parentRef];
                        
                        driveFile.mimeType = @"application/octet-stream";
                        NSString * caseInsensiveUsername = [name caseInsensitivize];
                        NSString * filename = [caseInsensiveUsername stringByAppendingPathExtension: IDENTITY_EXTENSION];
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
                                          [_progressView removeView];
                                          _progressView = nil;
                                          
                                          if (error == nil) {
                                              [UIUtils showToastKey:@"identity_successfully_backed_up_to_google_drive" duration:2];
                                          } else {
                                              [UIUtils showToastKey:@"could_not_backup_identity_to_google_drive" duration:2];
                                          }
                                      }];
                        
                    }
                }];
                
            }
            
            
        }];
    }];
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}


@end
