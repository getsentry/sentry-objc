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

- (BOOL) isCustomReport:(NSDictionary *)report
{
    NSString *reportType = [report objectForKeyPath:@"report/type"];
    return [reportType isEqualToString:@"custom"];
}

- (NSDictionary *)getRequiredAttributes:(NSDictionary *)report
{
    NSMutableDictionary *attributes = [NSMutableDictionary new];
    
    NSString *message;
    NSString *level;
    
    if([self isCustomReport:report])
    {
        message = report[@"message"];
        level = report[@"level"];
    }
    else
    {
        message = [report objectForKeyPath:@"crash/error/reason"];
        level = @"fatal";
    }

    attributes[@"event_id"] = [[report objectForKeyPath:@"report/id"] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    attributes[@"timestamp"] = [report objectForKeyPath:@"report/timestamp"];
    attributes[@"platform"] = @"objc"; // TODO: Use @"system/system_name" ?
    attributes[@"message"] = message;
    attributes[@"level"] = level;
    
    return attributes;
}

- (NSDictionary *)getOptionalAttributes:(NSDictionary *)report
{
    NSString *unset = nil;

    NSMutableDictionary *attributes = [NSMutableDictionary new];

    attributes[@"logger"] = unset;
    attributes[@"culprit"] = unset;
    attributes[@"server_name"] = [report objectForKeyPath:@"system/CFBundleIdentifier"];
    attributes[@"release"] = [report objectForKeyPath:@"system/CFBundleVersion"];
    attributes[@"tags"] = [report objectForKeyPath:@"user/tags"];
    attributes[@"modules"] = unset;
    attributes[@"extra"] = [report objectForKeyPath:@"user/extra"];
    attributes[@"fingerprint"] = unset;
    
    return attributes;
}

- (NSDictionary *)getUserInterface:(NSDictionary *)report
{
    return [report objectForKeyPath:@"user/sentry_user"];
}

- (NSDictionary *)getAppleCrashReportInterface:(NSDictionary *)report
{
    NSMutableDictionary *interface = [NSMutableDictionary new];
    
    interface[@"crash"] = report[@"crash"];
    interface[@"binary_images"] = report[@"binary_images"];
    interface[@"system"] = report[@"system"];
    
    return interface;
}

- (NSDictionary *)getStackTraceInterface:(NSArray *)reportBacktrace
{
    NSMutableArray *frames = [NSMutableArray new];
    for(NSString *function in reportBacktrace)
    {
        [frames addObject:@{@"function": function}];
    }
    return @{@"frames": frames};
}

- (NSArray *)getRuntimeExceptionInterface:(NSDictionary *)report
{
    NSDictionary *userReported = [report objectForKeyPath:@"crash/error/user_reported"];
    if (!userReported)
    {
        return nil;
    }

    NSMutableDictionary *interface = [NSMutableDictionary new];

    interface[@"type"] = userReported[@"name"];
    interface[@"value"] = [report objectForKeyPath:@"crash/error/reason"];
    interface[@"stacktrace"] = [self getStackTraceInterface:userReported[@"backtrace"]];
    
    return @[interface];
}

- (NSDictionary *)getInterfaces:(NSDictionary *)report
{
    NSMutableDictionary *interfaces = [NSMutableDictionary new];
    interfaces[@"user"] = [self getUserInterface:report];
    interfaces[@"applecrashreport"] = [self getAppleCrashReportInterface:report];
    interfaces[@"breadcrumbs"] = [report objectForKeyPath:@"user/breadcrumbs"];
    NSArray *runtimeExceptions = [self getRuntimeExceptionInterface:report];
    if (runtimeExceptions)
    {
        interfaces[@"runtime_exception"] = runtimeExceptions;
    }
    return interfaces;
}

- (NSDictionary *)convertReport:(NSDictionary *)report
{
    NSMutableDictionary *convertedReport = [NSMutableDictionary new];

    [convertedReport addEntriesFromDictionary:[self getRequiredAttributes:report]];
    if(![self isCustomReport:report])
    {
        [convertedReport addEntriesFromDictionary:[self getOptionalAttributes:report]];
        [convertedReport addEntriesFromDictionary:[self getInterfaces:report]];
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
