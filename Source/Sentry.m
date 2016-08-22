//
//  Sentry.m
//  Sentry-ObjC
//
//  Copyright © 2016 Sentry. All rights reserved.
//

#import "Sentry.h"
#import "KSCrashInstallationSentry.h"
#import "KSCrashAdvanced.h"
#import "RFC3339DateTool.h"
#import "SentryRequest.h"


#define BREADCRUMB_QUEUE_SIZE 10

static KSCrashInstallationSentry *installation = nil;

static int lastBreadcrumbIndex = 0;
static char breadcrumbFilenameBuffer[1000];
static char *breadcrumbFilenameIndexPtr = breadcrumbFilenameBuffer;

static void onCrash(const KSCrashReportWriter* writer)
{
    if(lastBreadcrumbIndex > 0)
    {
        int lowestEventIndex = lastBreadcrumbIndex - BREADCRUMB_QUEUE_SIZE;
        if(lowestEventIndex <= 0)
        {
            lowestEventIndex = 1;
        }
        writer->beginArray(writer, "breadcrumbs");
        for(int i = lowestEventIndex; i <= lastBreadcrumbIndex; i++)
        {
            sprintf(breadcrumbFilenameIndexPtr, "%d", i);
            writer->addJSONFileElement(writer, NULL, breadcrumbFilenameBuffer);
        }
        writer->endContainer(writer);
    }
}

@implementation Sentry

static NSMutableDictionary* userInfo;

+ (void)installWithDsn:(NSString *)dsn {
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        installation = [[KSCrashInstallationSentry alloc] init];
        if([Sentry initializeBreadcrumbs])
        {
            userInfo = [NSMutableDictionary new];
            installation.dsn = [SentryRequest cleanupDSN:dsn];
            installation.onCrash = onCrash;
            [installation install];
            [Sentry sendQueuedEvents];
        }
        else
        {
            NSLog(@"Sentry: Error initializing breadcrumbs. Crash logging disabled.");
        }
    });
}

+ (BOOL) ensureDirectoryExists:(NSString*) path
{
    NSError* error = nil;
    NSFileManager* fm = [NSFileManager defaultManager];
    
    if(![fm fileExistsAtPath:path])
    {
        if(![fm createDirectoryAtPath:path
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error])
        {
            NSLog(@"Sentry: Could not create directory %@: %@.", path, error);
            return NO;
        }
    }
    
    return YES;
}

+ (BOOL) initializeBreadcrumbs
{
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    
    NSArray* directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                               NSUserDomainMask,
                                                               YES);
    if([directories count] == 0)
    {
        NSLog(@"Sentry: Could not locate cache directory path.");
        return NO;
    }

    NSString* cachePath = [directories objectAtIndex:0];
    if([cachePath length] == 0)
    {
        NSLog(@"Sentry: Could not locate cache directory path.");
        return NO;
    }

    NSString* storePathEnd = [@"Breadcrumbs" stringByAppendingPathComponent:bundleName];
    NSString* storePath = [cachePath stringByAppendingPathComponent:storePathEnd];
    if([storePath length] == 0)
    {
        NSLog(@"Sentry: Could not determine report files path.");
        return NO;
    }

    if(![Sentry ensureDirectoryExists:storePath])
    {
        return NO;
    }

    NSString* baseFilename = [storePath stringByAppendingPathComponent:@"breadcrumbjsondata."];
    strcpy(breadcrumbFilenameBuffer, [baseFilename cStringUsingEncoding:NSUTF8StringEncoding]);
    breadcrumbFilenameIndexPtr = breadcrumbFilenameBuffer + strlen(breadcrumbFilenameBuffer);
    return YES;
}

+ (void)addBreadcrumbOfCategory:(const NSString *)category level:(const NSString *)level message:(const NSString *)message data:(const NSDictionary *)data
{
    if(category == nil)
    {
        category = @"unknown";
    }

    NSError *error = nil;
    NSMutableDictionary *jsonDict = [NSMutableDictionary new];
    jsonDict[@"timestamp"] = [RFC3339DateTool stringFromDate:[NSDate new]];
    jsonDict[@"category"] = category;
    if(level != nil)
    {
        jsonDict[@"level"] = level;
    }
    if(data != nil)
    {
        jsonDict[@"data"] = data;
    }
    if(message != nil)
    {
        jsonDict[@"message"] = message;
    }
    NSData *saveData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&error];
    if(saveData && !error)
    {
        @synchronized (installation) {
            int nextBreadcrumbIndex = lastBreadcrumbIndex + 1;
            NSString *path = [NSString stringWithFormat:@"%s%d", breadcrumbFilenameBuffer, nextBreadcrumbIndex];
            [saveData writeToFile:path options:NSDataWritingAtomic error:&error];
            if(error)
            {
                NSLog(@"Sentry: Error writing breadcrumb: %@", error);
            }
            else
            {
                lastBreadcrumbIndex = nextBreadcrumbIndex;
            }
        }
    }
    else
    {
        NSLog(@"Sentry: Error serializing breadcrumb: %@", error);
    }
}

+ (void) logNavigationFrom:(NSString *)from to:(NSString *)to level:(NSString *)level
{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"to"] = to;
    if(from)
    {
        data[@"from"] = from;
    }

    [Sentry addBreadcrumbOfCategory:@"navigation" level:level message:nil data:data];
}

+ (void) logUIEventOfType:(NSString *)type withTarget:(NSString *)target level:(NSString *)level
{
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"type"] = type;
    if(target)
    {
        data[@"target"] = target;
    }
    
    [Sentry addBreadcrumbOfCategory:@"ui_event" level:level message:nil data:data];
}

+ (void) logMessage:(NSString *)message level:(const NSString *)level
{
    [Sentry addBreadcrumbOfCategory:@"log" level:level message:message data:nil];
}

+ (void) logDebug:(NSString *)message
{
    [self logMessage:message level:@"debug"];
}

+ (void) logInfo:(NSString *)message;
{
    [self logMessage:message level:@"info"];
}

+ (void) logWarning:(NSString *)message;
{
    [self logMessage:message level:@"warning"];
}

+ (void) logError:(NSString *)message;
{
    [self logMessage:message level:@"error"];
}

+ (void) logFatal:(NSString *)message;
{
    [self logMessage:message level:@"fatal"];
}

+ (void) reportUserException:(NSString*) name
                      reason:(NSString*) reason
                    platform:(NSString*) platform
                  lineOfCode:(NSString*) lineOfCode
                  stackTrace:(NSArray*) stackTrace
            terminateProgram:(BOOL) terminateProgram
{
    [[KSCrash sharedInstance] reportUserException:name
                                           reason:reason
                                          language:platform
                                       lineOfCode:lineOfCode
                                       stackTrace:stackTrace
                                 terminateProgram:terminateProgram];

    // If the app didn't terminate, send this crash report.
    [Sentry sendQueuedEvents];
}

+ (void) sendQueuedEvents
{
    [installation sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
        if(completed)
        {
            NSLog(@"Sentry: %lu reports sent", (unsigned long)filteredReports.count);
        }
        else
        {
            NSLog(@"Sentry: Failed to send reports: %@", error);
        }
    }];
}


+ (void) addCrashUserInfoWithKey:(NSString *)key value:(id)value
{
    userInfo[key] = value;
    [KSCrash sharedInstance].userInfo = userInfo;
}

+ (void) setCrashUserID:(NSString *)userID name:(NSString *)name email:(NSString *)email extra:(NSDictionary *)extra
{
    NSMutableDictionary *user = [extra mutableCopy];
    if (!user)
    {
        user = [NSMutableDictionary new];
    }
    user[@"id"] = userID;
    user[@"username"] = name;
    user[@"email"] = email;
    
    [Sentry addCrashUserInfoWithKey:@"sentry_user" value:user];
}

+ (void) setCrashTags:(NSDictionary *)tags
{
    [Sentry addCrashUserInfoWithKey:@"tags" value:tags];
}

+ (void) setCrashExtra:(NSDictionary *)extra
{
    [Sentry addCrashUserInfoWithKey:@"extra" value:extra];
}

@end
