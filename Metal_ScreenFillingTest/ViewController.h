//
//  ViewController.h
//  Metal_ScreenFillingTest
//
//  Created by Radek Pistelak on 09.04.16.
//  Copyright © 2016 ran. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "View.h"

@interface ViewController : UIViewController

@property (nonatomic, strong) View *view;

@property (strong) dispatch_semaphore_t displaySemaphore;

@end

