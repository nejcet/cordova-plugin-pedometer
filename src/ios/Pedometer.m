//
//  Pedometer.m
//  Copyright (c) 2014 Lee Crossley - http://ilee.co.uk
//

#import "Cordova/CDV.h"
#import "Cordova/CDVViewController.h"
#import "CoreMotion/CoreMotion.h"
#import "Pedometer.h"

@interface Pedometer ()
    @property (nonatomic, strong) CMPedometer *pedometer;
@end

@implementation Pedometer

- (CMPedometer*) pedometer {
    if (_pedometer == nil) {
        _pedometer = [[CMPedometer alloc] init];
    }
    return _pedometer;
}

- (void) isStepCountingAvailable:(CDVInvokedUrlCommand*)command;
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[CMPedometer isStepCountingAvailable]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) isDistanceAvailable:(CDVInvokedUrlCommand*)command;
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[CMPedometer isDistanceAvailable]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) isFloorCountingAvailable:(CDVInvokedUrlCommand*)command;
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[CMPedometer isFloorCountingAvailable]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) startPedometerUpdates:(CDVInvokedUrlCommand*)command;
{
    __block CDVPluginResult* pluginResult = nil;

    [self.pedometer startPedometerUpdatesFromDate:[NSDate date] withHandler:^(CMPedometerData *pedometerData, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error)
            {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            }
            else
            {
                NSDictionary* pedestrianData = @{
                    @"startDate": [NSString stringWithFormat:@"%f", [pedometerData.startDate timeIntervalSince1970] * 1000],
                    @"endDate": [NSString stringWithFormat:@"%f", [pedometerData.endDate timeIntervalSince1970] * 1000],
                    @"numberOfSteps": [CMPedometer isStepCountingAvailable] && pedometerData.numberOfSteps ? pedometerData.numberOfSteps : [NSNumber numberWithInt:0],
                    @"distance": [CMPedometer isDistanceAvailable] && pedometerData.distance ? pedometerData.distance : [NSNumber numberWithInt:0],
                    @"floorsAscended": [CMPedometer isFloorCountingAvailable] && pedometerData.floorsAscended ? pedometerData.floorsAscended : [NSNumber numberWithInt:0],
                    @"floorsDescended": [CMPedometer isFloorCountingAvailable] && pedometerData.floorsDescended ? pedometerData.floorsDescended : [NSNumber numberWithInt:0]
                };
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:pedestrianData];
                [pluginResult setKeepCallbackAsBool:true];
            }

            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        });
    }];
}

- (void) stopPedometerUpdates:(CDVInvokedUrlCommand*)command;
{
    [self.pedometer stopPedometerUpdates];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void) queryData:(CDVInvokedUrlCommand*)command;
{
    NSDictionary* args = [command.arguments objectAtIndex:0];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSDate* startDate = [dateFormatter dateFromString:[args objectForKey:@"startDate"]];
    NSDate* endDate = [dateFormatter dateFromString:[args objectForKey:@"endDate"]];
    
    __block CDVPluginResult* pluginResult = nil;
    
    [self.pedometer queryPedometerDataFromDate:startDate toDate:endDate withHandler:^(CMPedometerData *pedometerData, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error)
            {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            }
            else
            {
                NSDictionary* pedestrianData = @{
                                                 @"numberOfSteps": [CMPedometer isStepCountingAvailable] && pedometerData.numberOfSteps ? pedometerData.numberOfSteps : [NSNumber numberWithInt:0],
                                                 @"distance": [CMPedometer isDistanceAvailable] && pedometerData.distance ? pedometerData.distance : [NSNumber numberWithInt:0],
                                                 @"floorsAscended": [CMPedometer isFloorCountingAvailable] && pedometerData.floorsAscended ? pedometerData.floorsAscended : [NSNumber numberWithInt:0],
                                                 @"floorsDescended": [CMPedometer isFloorCountingAvailable] && pedometerData.floorsDescended ? pedometerData.floorsDescended : [NSNumber numberWithInt:0]
                                                 };
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:pedestrianData];
            }
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        });
    }];
}



#define LOW_LEVEL_MIN_STEP_COUNT 100
#define HIGH_LEVEL_MIN_STEP_COUNT 100
#define LOW_LEVEL_TIME_INTERVAL 60*60
#define HIGH_LEVEL_TIME_INTERVAL 1*60

- (void) queryHistoryData:(CDVInvokedUrlCommand*)command;
{
    
    NSDictionary* args = [command.arguments objectAtIndex:0];

    NSDateFormatter *dateFormatter = [self getIsoDateFormatter];
    NSDate* startDate = [dateFormatter dateFromString:[args objectForKey:@"startDate"]];
    NSDate* endDate = [dateFormatter dateFromString:[args objectForKey:@"endDate"]];
    
    __block CDVPluginResult* pluginResult = nil;
    
    NSDate *started = [NSDate date];
    
    [self queryHistoryDataWithStartDate:startDate EndDate:endDate Completion:^(NSArray *values) {
        NSMutableArray *normalizedValues = [NSMutableArray array];
        for (NSDictionary *value in values) {
            [normalizedValues addObject:[self normalizeValue:value]];
        }
        NSTimeInterval diff = [[NSDate date] timeIntervalSince1970] - [started timeIntervalSince1970];
        NSLog(@"values count: %lu, diff: %f", (unsigned long)[normalizedValues count], diff);
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:normalizedValues];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];

}

-(NSDateFormatter*)getIsoDateFormatter {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    return dateFormatter;
}

-(NSDictionary*)normalizeValue: (NSDictionary*)value {
    NSDateFormatter *dateFormatter = [self getIsoDateFormatter];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:value];
    NSDate *start = [dict objectForKey:@"start"];
    NSDate *end = [dict objectForKey:@"start"];
    [dict setValue:[dateFormatter stringFromDate:start] forKey:@"start"];
    [dict setValue:[dateFormatter stringFromDate:end] forKey:@"end"];
    return (NSDictionary*)dict;
}


-(void)queryHistoryDataWithStartDate:(NSDate*)startDate EndDate:(NSDate*)endDate Completion:(void (^)(NSArray*values))completionBlock
{
    NSMutableArray *values = [NSMutableArray array];
    
    [self queryDataWithStartDate:startDate EndDate:endDate TimeInterval:LOW_LEVEL_TIME_INTERVAL Completion:^(NSArray *lowLevelStepData) {
        for (NSUInteger iLowLevel = 0; iLowLevel < [lowLevelStepData count]; iLowLevel++) {
            NSDictionary *lowLevelDict = [lowLevelStepData objectAtIndex:iLowLevel];
            
            
            if ([lowLevelDict[@"steps"] integerValue] >= LOW_LEVEL_MIN_STEP_COUNT) {
                [self queryDataWithStartDate:lowLevelDict[@"start"] EndDate:lowLevelDict[@"end"] TimeInterval:HIGH_LEVEL_TIME_INTERVAL Completion:^(NSArray *highLevelStepData) {
                    
                    for (NSUInteger iHighLevel=0; iHighLevel < [highLevelStepData count]; iHighLevel++) {
                        
                        NSMutableDictionary *highLevelDict = [NSMutableDictionary dictionaryWithDictionary:[highLevelStepData objectAtIndex:iHighLevel]];
                        
                        [values addObject:highLevelDict];
                        if ( iLowLevel+1 ==  [lowLevelStepData count] && iHighLevel+1 == [highLevelStepData count] ) {
                            completionBlock(values);
                        }
                        
                    }
                    
                }];
                
            } else {
                
                NSArray *highLevelRange = [self getDateRangesWithStartDate:lowLevelDict[@"start"] EndDate:lowLevelDict[@"end"] TimeInterval:HIGH_LEVEL_TIME_INTERVAL];
                
                for (NSUInteger iHighLevel=0; iHighLevel < [highLevelRange count]; iHighLevel++) {
                    
                    NSMutableDictionary *highLevelDict = [NSMutableDictionary dictionaryWithDictionary:[highLevelRange objectAtIndex:iHighLevel]];
                    highLevelDict[@"steps"] = @0;
                    if (iHighLevel == 0) {
                        highLevelDict[@"steps"] = lowLevelDict[@"steps"];
                        highLevelDict[@"summarized"] = @1;
                    }
                    [values addObject:highLevelDict];
                    
                    if ( iLowLevel+1 ==  [lowLevelStepData count] && iHighLevel+1 == [highLevelRange count] ) {
                        completionBlock(values);
                    }
                    
                }
                
            }
        }
    }];
}

-(void)queryDataWithStartDate:(NSDate*)startDate EndDate:(NSDate*)endDate TimeInterval:(NSTimeInterval)interval Completion:(void (^)(NSArray*stepData))completionBlock
{
    NSArray *dateRanges = [self getDateRangesWithStartDate:startDate EndDate:endDate TimeInterval:interval];
    NSMutableArray *values = [NSMutableArray array];
    
    for (int i = 0; i < [dateRanges count]; i++) {
        NSMutableDictionary *range = [NSMutableDictionary dictionaryWithDictionary:[dateRanges objectAtIndex:i]];
        
        [self.pedometer queryPedometerDataFromDate:range[@"start"] toDate:range[@"end"] withHandler:^(CMPedometerData *pedometerData, NSError *error) {
            range[@"steps"] = [CMPedometer isStepCountingAvailable] && pedometerData.numberOfSteps ? pedometerData.numberOfSteps : [NSNumber numberWithInt:0];
            [values addObject:range];
            
            if (i+1 == [dateRanges count]) {
                completionBlock((NSArray*)values);
            }
        }];
        
    }
}

-(NSArray*)getDateRangesWithStartDate:(NSDate*)startDate EndDate:(NSDate*)endDate TimeInterval:(NSTimeInterval)interval
{
    NSMutableArray *dateRanges = [NSMutableArray array];
    
    NSTimeInterval startTime = [startDate timeIntervalSince1970];
    NSTimeInterval endTime = [endDate timeIntervalSince1970];
    NSTimeInterval diff = endTime - startTime;
        
    if (diff <= 0) {
        return (NSArray*)dateRanges;
    }
        
    NSUInteger countItems = diff > interval ? ceil(diff / interval) : 1;
    for (int i = 0; i < countItems; i++) {
        NSTimeInterval currentTimeInterval = startTime + (i*interval);
        NSDate *_startDate =  [NSDate dateWithTimeIntervalSince1970:currentTimeInterval];
        NSDate *_endDate =  [NSDate dateWithTimeIntervalSince1970:currentTimeInterval+interval - 0.99];
        [dateRanges addObject:@{@"start": _startDate, @"end": _endDate }];
    }
    return (NSArray*)dateRanges;
}




@end
