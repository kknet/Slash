//
//  SLHEncoderVPXOptions.m
//  Slash
//
//  Created by Terminator on 2019/05/27.
//  Copyright © 2019年 digital-pers0n. All rights reserved.
//

#import "SLHEncoderVPXOptions.h"

@implementation SLHEncoderVPXOptions

- (id)copyWithZone:(NSZone *)zone {
    SLHEncoderVPXOptions *obj = [super copyWithZone:zone];
    obj->_twoPass = _twoPass;
    obj->_quality = _quality;
    obj->_speed = _speed;
    obj->_lookAhead = _lookAhead;
    return obj;
}

@end