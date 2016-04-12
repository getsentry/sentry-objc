//
//  Sentry.h
//  Sentry-ObjC
//
//  Copyright © 2016 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Primary interface for the Sentry client.
 */
@interface Sentry : NSObject

/**
 * Install the Sentry client.
 * Note: Multiple calls to this method will be ignored.
 *
 * @param dsn Format {PROTOCOL}://{PUBLIC_KEY}:{SECRET_KEY}@{HOST}/{PATH}{PROJECT_ID}
 */
+ (void) installWithDsn:(NSString *)dsn;

/**
 * Set the user info that will be sent with a crash report.
 */
+ (void) setCrashUserID:(NSString *)userID name:(NSString *)name email:(NSString *)email extra:(NSDictionary *)extra;

/**
 * Set any tags that will be attached to a crash report.
 * Note: Only use JSON-compatible objects (strings, numbers, dictionaries, arrays).
 */
+ (void) setCrashTags:(NSDictionary *)tags;

/**
 * Set any extra info that will be attached to a crash report.
 * Note: Only use JSON-compatible objects (strings, numbers, dictionaries, arrays).
 */
+ (void) setCrashExtra:(NSDictionary *)extra;

/**
 * Log a debug message event.
 *
 * @param message The message to record.
 */
+ (void) logDebug:(NSString *)message;

/**
 * Log an info message event.
 *
 * @param message The message to record.
 */
+ (void) logInfo:(NSString *)message;

/**
 * Log a warning message event.
 *
 * @param message The message to record.
 */
+ (void) logWarning:(NSString *)message;

/**
 * Log an error message event.
 *
 * @param message The message to record.
 */
+ (void) logError:(NSString *)message;

/**
 * Log a fatal message event.
 *
 * @param message The message to record.
 */
+ (void) logFatal:(NSString *)message;

/**
 * Log a navigation event.
 *
 * @param from Where you are navigating from.
 * @param to Where you are navigating to.
 */
+ (void) logNavigationFrom:(NSString *)from to:(NSString *)to;

/**
 * Log a UI event.
 *
 * @param type The event type.
 * @param target The target of this event.
 */
+ (void) logUIEventOfType:(NSString *)type withTarget:(NSString *)target;

/** Report a custom, user defined exception.
 *
 * @param name The exception name.
 *
 * @param reason A description of why the exception occurred.
 *
 * @param language A unique language identifier.
 *
 * @param lineOfCode A copy of the offending line of code (nil = ignore).
 *
 * @param stackTrace An array of strings representing the call stack leading to the exception (nil = ignore).
 *
 * @param terminateProgram If true, do not return from this function call. Terminate the program instead.
 */
+ (void) reportUserException:(NSString*) name
                      reason:(NSString*) reason
                    language:(NSString*) language
                  lineOfCode:(NSString*) lineOfCode
                  stackTrace:(NSArray*) stackTrace
            terminateProgram:(BOOL) terminateProgram;

@end

//! Project version number for Sentry.
FOUNDATION_EXPORT double SentryVersionNumber;

//! Project version string for Sentry.
FOUNDATION_EXPORT const unsigned char SentryVersionString[];
