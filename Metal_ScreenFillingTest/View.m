//
//  View.m
//  Metal_ScreenFillingTest
//
//  Created by Radek Pistelak on 09.04.16.
//  Copyright © 2016 ran. All rights reserved.
//

#import "View.h"


@implementation View

+ (Class) layerClass
{
    return [CAMetalLayer class];
}

@end
