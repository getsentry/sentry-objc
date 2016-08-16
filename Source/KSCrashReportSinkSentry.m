//
//  KSCrashReportSinkSentry.m
//  Sentry-ObjC
//
//  Copyright © 2016 Sentry. All rights reserved.
//

#import "KSCrashReportSinkSentry.h"
#import "SentryRequest.h"
#import "Container+DeepSearch.h"
#import "KSReachabilityKSCrash.h"
#import "ReportInterpreter.h"

#define SENTRY_VERSION @"7"
#define CLIENT_VERSION @"1.0"

@interface KSCrashReportSinkSentry ()

@property NSString *dsn;
@property KSReachableOperationKSCrash *reachableOperation;

@end

@implementation KSCrashReportSinkSentry

+ (instancetype) sinkWithDsn:(NSString *) dsn {
    return [[KSCrashReportSinkSentry alloc] initWithDsn:dsn];
}

- (instancetype) initWithDsn:(NSString *) dsn {
    if((self = [super init])) {
        self.dsn = dsn;
    }
    return self;
}

- (id <KSCrashReportFilter>) defaultCrashReportFilterSet {
    return self;
}

- (NSDictionary *)getInterfaces:(ReportInterpreter *)interpreter
{
    NSMutableDictionary *interfaces = [NSMutableDictionary new];
    interfaces[@"exception"] = interpreter.exceptionInterface;
    interfaces[@"threads"] = interpreter.threadsInterface;
    interfaces[@"contexts"] = interpreter.contextsInterface;
    interfaces[@"breadcrumbs"] = interpreter.breadcrumbsInterface;
    interfaces[@"debug_meta"] = interpreter.debugInterface;

    return interfaces;
}

- (NSDictionary *)convertReport:(NSDictionary *)report
{
    ReportInterpreter *interpreter = [ReportInterpreter interpreterForReport:report];
    NSMutableDictionary *convertedReport = [NSMutableDictionary new];

    [convertedReport addEntriesFromDictionary:interpreter.requiredAttributes];
    if(!interpreter.isCustomReport)
    {
        [convertedReport addEntriesFromDictionary:interpreter.optionalAttributes];
        [convertedReport addEntriesFromDictionary:[self getInterfaces:interpreter]];
    }
    
    return convertedReport;
}

- (void) filterReports:(NSArray *)reports
          onCompletion:(KSCrashReportFilterCompletion)onCompletion
{
    NSMutableArray *requests = [NSMutableArray new];
    for (NSDictionary *report in reports) {
        SentryRequest *request = [SentryRequest requestWithDSN:self.dsn report:[self convertReport:report]];
        if(request)
        {
            [requests addObject:request];
        }
    }

    if(requests.count == 0)
    {
        onCompletion(reports, YES, nil);
        return;
    }
    
    NSString *host = [[requests[0] url] host];
    self.reachableOperation = [KSReachableOperationKSCrash operationWithHost:host allowWWAN:YES block:^
       {
           __block int remainingCount = (int)requests.count;
           __block NSError *lastError;
           NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

           for (SentryRequest *request in requests)
           {
               NSURLSessionTask *task = [request newSendTaskWithSession:session onCompletion:^(NSError *error) {
                   remainingCount--;
                   if(error)
                   {
                       lastError = error;
                   }
                   if(remainingCount <= 0)
                   {
                       onCompletion(reports, !lastError, lastError);
                   }
               }];
               [task resume];
           }
       }];
}

@end
