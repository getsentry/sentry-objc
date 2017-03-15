Sentry Objective-C  Client
==================

***Please consider using our [Swift Client](https://github.com/getsentry/sentry-swift) this repo is only maintained for iOS Version < 8.0.

The Swift Client will also work with Objective-C projects.***

Installation
------------

### Using [CocoaPods](http://cocoapods.org)

```ruby
platform :ios, '8.0'
use_frameworks!

pod 'Sentry', :git => 'git@github.com:getsentry/sentry-objc.git'
```

Using
-----

### Swift Usage

```swift
import Sentry

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Log all crashes to Sentry
        Sentry.installWithDsn("https://mydsnuser:mydsnpass@app.getsentry.com/myprojectid");
        return true
    }

    func sendLogEventsToSentry() {
        Sentry.logDebug("Send a debug log event to Sentry!")
        Sentry.logInfo("Send an info log event to Sentry!")
        Sentry.logWarning("Send a warning log event to Sentry!")
        Sentry.logError("Send an error log event to Sentry!")
        Sentry.logFatal("Send a fatal log event to Sentry!")

        Sentry.logNavigationFrom("main" to: "settings")

        Sentry.logUIEventOfType("touch" withTarget: "start button")
    }
```

### Objective-C Usage

```objective-c
#import "Sentry.h"

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Log all crashes to Sentry
    [Sentry installWithDsn:@"https://mydsnuser:mydsnpass@app.getsentry.com/myprojectid"];
    return YES;
}

- (void)sendLogEventsToSentry {
    [Sentry logDebug:@"Send a debug log event to Sentry!"];
    [Sentry logInfo:@"Send an info log event to Sentry!"];
    [Sentry logWarning:@"Send a warning log event to Sentry!"];
    [Sentry logError:@"Send an error log event to Sentry!"];
    [Sentry logFatal:@"Send a fatal log event to Sentry!"];

    [Sentry logNavigationFrom:@"main" to:@"settings"];

    [Sentry logUIEventOfType:@"touch" withTarget:@"start button"];
}
```


Uploading DSYMs
---------------

A DSYM can be uploaded to Sentry using [sentry-cli](https://github.com/getsentry/sentry-cli).

After installing [sentry-cli](https://github.com/getsentry/sentry-cli), you can create a simple bash script to upload your DSYMs

```bash
#!/bin/sh

API_KEY="my-api-key"
ORG_SLUG="my-org-slug"
PROJECT_SLUG="my-project-slug"


DSYM_FILE=$1

if [ "X$DSYM_FILE" = "X" ]; then
    echo "Usage: $0 <path to dsym>"
    exit 1
fi

set -e
set -u

if [ ! -d "$DSYM_FILE" ]; then
    echo "Error: DSYM not found: $DSYM_FILE"
    exit 1
fi

sentry-cli --api-key ${API_KEY} upload-dsym --org ${ORG_SLUG} --project ${PROJECT_SLUG} "${DSYM_FILE}"
```
