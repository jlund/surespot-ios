//
//  KeyFingerprint.m
//  surespot
//
//  Created by Adam on 12/23/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "KeyFingerprint.h"
#import "KeyFingerprintCollectionCell.h"

@interface KeyFingerprint()
@property (strong, nonatomic) NSString * fpData;
@property (strong, nonatomic) NSString * title;
@end

@implementation KeyFingerprint

-(id) initWithFingerprintData: (NSString *) hexData forTitle: (NSString *) title {
    self = [super init];
    if (self) {
        _title = title;
        if (hexData.length == 31) {
            hexData = [@"0" stringByAppendingString:hexData];
        }
        
        _fpData = hexData;
    }
    return self;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    KeyFingerprintCollectionCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"KeyFingerprintCollectionCell" forIndexPath:indexPath];
    NSString * text = [_fpData substringWithRange:NSMakeRange((4 * indexPath.section + indexPath.row)*2, 2)];
    cell.label.text = text;
    return cell;
}


- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 4;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 4;
}
@end