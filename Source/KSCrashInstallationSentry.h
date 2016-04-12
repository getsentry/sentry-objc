//
//  KSCrashInstallationSentry.h
//  Sentry-ObjC
//
//  Copyright © 2016 Sentry. All rights reserved.
//

#import <KSCrash/KSCrashInstallation.h>

/**
 * KSCrash installation for sentry.
 */
@interface KSCrashInstallationSentry : KSCrashInstallation

@property NSString* dsn;

@end
