//
//  SentryRequest.m
//  Sentry
//
//  Created by karl on 2016-03-08.
//  Copyright © 2016 Sentry. All rights reserved.
//

#import "SentryRequest.h"
#import "NSData+GZip.h"
#import "NSError+SimpleConstructor.h"

#define SENTRY_VERSION @"7"
#define CLIENT_VERSION @"1.0"

@interface SentryRequest ()

@property NSURLRequest *request;

@end

@implementation SentryRequest

static NSURL *extractURLFromDSN(NSString *dsn)
{
    NSURL *url = [NSURL URLWithString:dsn];
    NSString *projectID = url.pathComponents[1];
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = url.scheme;
    components.host = url.host;
    components.port = url.port;
    components.path = [NSString stringWithFormat:@"/api/%@/store/", projectID];
    return components.URL;
}

static NSString *newHeaderPart(NSString *key, id value)
{
    return [NSString stringWithFormat:@"%@=%@", key, value];
}

static NSString *newAuthHeader(NSURL *url)
{
    NSMutableString *string = [NSMutableString stringWithString:@"Sentry "];
    
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_version", SENTRY_VERSION)];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_client", [NSString stringWithFormat:@"raven-objc/%@", CLIENT_VERSION])];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_timestamp", [NSNumber numberWithInt:(int)[[NSDate date] timeIntervalSince1970]])];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_key", url.user)];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_secret", url.password)];
    
    [string deleteCharactersInRange:NSMakeRange([string length]-1, 1)];
    return string;
}

static NSData *newHTTPBodyFromReport(NSDictionary *report)
{
    NSError *error = nil;
    NSData* body = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&error];
    if(error)
    {
        NSLog(@"Sentry: newHTTPBodyFromReport: %@", error);
    }
    return body;
}

static bool isSuccessfulHTTPResponse(NSHTTPURLResponse *urlResponse)
{
    if(urlResponse.statusCode >= 200 && urlResponse.statusCode < 300)
    {
        return true;
    }
    if(urlResponse.statusCode >= 400 && urlResponse.statusCode < 500)
    {
        // Error code 4xx means the client is doing something wrong. Log the error
        // and return true to discard the event so that it doesn't get stuck in the queue forever.
        NSLog(@"Sentry: Error: Returned http status %@", urlResponse);
        return true;
    }
    return false;
}

+ (NSString *)cleanupDSN:(NSString *)dsn
{
    if(!dsn)
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"DSN is nil" userInfo:nil];
    }
    dsn = [dsn stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSSet *allowedSchemes = [NSSet setWithObjects:@"http", @"https", nil];
    NSURL *url = [NSURL URLWithString:dsn];
    if(!url.scheme)
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"URL scheme of DSN is missing" userInfo:nil];
    }
    if(![allowedSchemes containsObject:url.scheme])
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Unrecognized URL scheme in DSN" userInfo:nil];
    }
    if(!url.host || url.host.length == 0)
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Host component of DSN is missing" userInfo:nil];
    }
    if(!url.user)
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"User component of DSN is missing" userInfo:nil];
    }
    if(!url.password)
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Password component of DSN is missing" userInfo:nil];
    }
    if(url.pathComponents.count < 2)
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Project ID path component of DSN is missing" userInfo:nil];
    }
    return dsn;
}

+ (instancetype)requestWithDSN:(NSString *)dsn report:(NSDictionary *)report
{
    return [[SentryRequest alloc] initWithDSN:dsn report:report];
}

- (instancetype)initWithDSN:(NSString *)dsn report:(NSDictionary *)report
{
    dsn = [SentryRequest cleanupDSN:dsn];
    if(!report)
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Report is nil" userInfo:nil];
    }
    NSURL *dsnURL = [NSURL URLWithString:dsn];
    NSURL *hostUrl = extractURLFromDSN(dsn);
    NSString *authHeader = newAuthHeader(dsnURL);
    NSData *body = newHTTPBodyFromReport(report);

    if(!dsnURL || !hostUrl || !authHeader || !body)
    {
        return nil;
    }
    
    if((self = [super init]))
    {

        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:hostUrl
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                           timeoutInterval:15];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:authHeader forHTTPHeaderField:@"X-Sentry-Auth"];
        [request setValue:@"KSCrashReporter" forHTTPHeaderField:@"User-Agent"];
        
        [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        body = [body gzippedWithCompressionLevel:-1 error:nil];
        request.HTTPBody = body;
        
        self.url = hostUrl;
        self.request = request;
    }
    return self;
}

- (NSURLSessionTask *)newSendTaskWithSession:(NSURLSession *)session onCompletion:(void (^)(NSError *error))onCompletion
{
    if(!onCompletion)
    {
        onCompletion = ^(__unused NSError *error) {};
    }

    return [session dataTaskWithRequest:self.request completionHandler:^(__unused NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse*)response;
        if(!error && !isSuccessfulHTTPResponse(urlResponse))
        {
            onCompletion([NSError errorWithDomain:@"newSendTaskWithReport" code:urlResponse.statusCode description:[NSString stringWithFormat:@"%@", urlResponse]]);
        }
        onCompletion(error);
    }];
}

@end
