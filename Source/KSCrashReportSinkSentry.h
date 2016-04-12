//
//  KSCrashReportSinkSentry.h
//  Sentry-ObjC
//
//  Copyright © 2016 Sentry. All rights reserved.
//

#import <KSCrash/KSCrashReportFilter.h>

/**
 * KSCrash report sink for Sentry.
 */
@interface KSCrashReportSinkSentry : NSObject <KSCrashReportFilter>

+ (instancetype) sinkWithDsn:(NSString *) dsn;

- (instancetype) initWithDsn:(NSString *) dsn;

- (id <KSCrashReportFilter>) defaultCrashReportFilterSet;

@end
