//
//  KSCrashInstallationSentry.m
//  Sentry-ObjC
//
//  Copyright © 2016 Sentry. All rights reserved.
//

#import "KSCrashInstallationSentry.h"
#import "KSCrashInstallation+Private.h"
#import "KSCrashReportSinkSentry.h"

@implementation KSCrashInstallationSentry

- (id) init
{
    return [super initWithRequiredProperties:@[@"dsn"]];
}

- (id<KSCrashReportFilter>) sink
{
    KSCrashReportSinkSentry* sink = [KSCrashReportSinkSentry sinkWithDsn:self.dsn];
    return [sink defaultCrashReportFilterSet];
}

@end
