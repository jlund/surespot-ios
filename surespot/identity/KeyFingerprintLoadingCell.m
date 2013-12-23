//
//  KeyFingerprintLoadingCell.m
//  surespot
//
//  Created by Adam on 12/23/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "KeyFingerprintLoadingCell.h"

@interface KeyFingerprintLoadingCell()
@property (strong, nonatomic) IBOutlet UILabel *keyFingerprintLoadingLabel;
@end

@implementation KeyFingerprintLoadingCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _keyFingerprintLoadingLabel.text = NSLocalizedString(@"loading", nil);

    }
    return self;
}


@end
