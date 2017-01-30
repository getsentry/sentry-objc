//
//  ViewController.m
//  OldObjcExample
//
//  Created by Daniel Griesser on 30/01/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import "ViewController.h"
#import "Sentry.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Sentry installWithDsn:@"your-dsn"];
}

- (IBAction)actionSendMessage:(id)sender {
    [Sentry logInfo:@"Send an info log event to Sentry!"];
}

- (IBAction)actionCrash:(id)sender {
    NSMutableArray *someArray = @[].mutableCopy;
    [someArray addObject:nil];
}

@end
