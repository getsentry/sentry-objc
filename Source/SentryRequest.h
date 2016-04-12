//
//  SentryRequest.h
//  Sentry
//
//  Created by karl on 2016-03-08.
//  Copyright © 2016 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * An HTTP request to the Sentry client API.
 */
@interface SentryRequest : NSObject

@property NSURL *url;

/**
 * Cleanup a DSN, validating it and removing any trailing whitespace.
 */
+ (NSString *)cleanupDSN:(NSString *)dsn;

/**
 * Create a request.
 *
 * @param dsn The DSN you got from Sentry.
 * @param report A JSON-encodable report.
 */
+ (instancetype)requestWithDSN:(NSString *)dsn report:(NSDictionary *)report;

/**
 * Initialize a request.
 *
 * @param dsn The DSN you got from Sentry.
 * @param report A JSON-encodable report.
 */
- (instancetype)initWithDSN:(NSString *)dsn report:(NSDictionary *)report;

/**
 * Create a send task for this request.
 *
 * @param session The URL session to create a task for.
 * @param onCompletion Called when the task completes (can be nil).
 * @return A URL session task. It's up to you to start it.
 */
- (NSURLSessionTask *)newSendTaskWithSession:(NSURLSession *)session onCompletion:(void (^)(NSError *error))onCompletion;

@end
