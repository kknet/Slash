//
//  MPVMetadataItem.h
//  Slash
//
//  Created by Terminator on 2019/10/21.
//  Copyright © 2019年 digital-pers0n. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPVMetadataItem : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier value:(NSString *)value;

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *value;

@end

NS_ASSUME_NONNULL_END
