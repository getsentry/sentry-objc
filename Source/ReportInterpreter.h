//
//  ReportInterpreter.h
//  Sentry
//
//  Created by Karl on 2016-07-11.
//

#import <Foundation/Foundation.h>

@interface ReportInterpreter : NSObject

+ (instancetype)interpreterForReport:(NSDictionary *)report;
- (instancetype)initWithReport:(NSDictionary *)report;

@property(readonly) NSDictionary *exceptionInterface;
@property(readonly) NSDictionary *threadsInterface;
@property(readonly) NSDictionary *contextsInterface;
@property(readonly) NSDictionary *breadcrumbsInterface;
@property(readonly) NSDictionary *debugInterface;

@property(readonly) NSDictionary *requiredAttributes;
@property(readonly) NSDictionary *optionalAttributes;
@property(readonly) BOOL isCustomReport;

@end
