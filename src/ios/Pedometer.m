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



#define HIGH_LEVEL_MIN_STEP_COUNT 75.0
#define LOW_LEVEL_TIME_INTERVAL 60.0*60.0
#define HIGH_LEVEL_TIME_INTERVAL 1.0*60.0

- (void) queryHistoryData:(CDVInvokedUrlCommand*)command;
{
    
    NSDictionary* args = [command.arguments objectAtIndex:0];

    NSDateFormatter *dateFormatter = [self getIsoDateFormatter];
    NSDate* startDate = [dateFormatter dateFromString:[args objectForKey:@"startDate"]];
    NSDate* endDate = [dateFormatter dateFromString:[args objectForKey:@"endDate"]];
    
    __block CDVPluginResult* pluginResult = nil;
    
    if ([CMPedometer isStepCountingAvailable]) {
        [self queryHistoryDataWithStartDate:startDate EndDate:endDate Completion:^(NSArray *values) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:values];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Step counting not available."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    

}

-(NSDateFormatter*)getIsoDateFormatter {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    return dateFormatter;
}

-(void)queryHistoryDataWithStartDate:(NSDate*)startDate EndDate:(NSDate*)endDate Completion:(void (^)(NSArray*values))completionBlock
{
    
    [self buildQueryDateRanges:startDate EndDate:endDate Completion:^(NSArray *ranges) {
        NSMutableArray *values = [NSMutableArray array];
        NSDateFormatter *dateFormatter = [self getIsoDateFormatter];
        
        for (NSUInteger i=0; i < [ranges count]; i++) {
            NSMutableDictionary *range = [NSMutableDictionary dictionaryWithDictionary:[ranges objectAtIndex:i]];

            [self.pedometer queryPedometerDataFromDate:range[@"start"] toDate:range[@"end"] withHandler:^(CMPedometerData *pedometerData, NSError *error) {
                
                NSNumber *numberOfSteps = [CMPedometer isStepCountingAvailable] && pedometerData.numberOfSteps ? pedometerData.numberOfSteps : [NSNumber numberWithInt:0];
                [range setObject:numberOfSteps forKey:@"numberOfSteps"];
                
                NSDate *start = [range objectForKey:@"start"];
                NSDate *end = [range objectForKey:@"end"];
                [range setValue:[dateFormatter stringFromDate:start] forKey:@"start"];
                [range setValue:[dateFormatter stringFromDate:end] forKey:@"end"];
                
                [values addObject:range];
                
                if (i+1 == [ranges count]) {
                    completionBlock((NSArray*)values);
                }
            }];

        }
        
    }];
}


-(void)buildQueryDateRanges:(NSDate*)startDate EndDate:(NSDate*)endDate Completion:(void (^)(NSArray*values))completionBlock
{
    NSTimeInterval diff = [endDate timeIntervalSince1970] - [startDate timeIntervalSince1970];
    
    if ( diff < LOW_LEVEL_TIME_INTERVAL) {
        completionBlock([self getDateRangesWithStartDate:startDate EndDate:endDate TimeInterval:HIGH_LEVEL_TIME_INTERVAL]);
    } else {
        NSMutableArray *ranges = [NSMutableArray array];
        
        [self queryDataWithStartDate:startDate EndDate:endDate TimeInterval:LOW_LEVEL_TIME_INTERVAL Completion:^(NSArray *lowLevelStepData) {
            
            for (NSDictionary *lowLevelDict in lowLevelStepData) {
                NSDate *_startDate = [lowLevelDict objectForKey:@"start"];
                NSDate *_endDate = [lowLevelDict objectForKey:@"end"];
                if ([_endDate timeIntervalSince1970] > [endDate timeIntervalSince1970]) {
                    _endDate = endDate;
                }
                
                if ([[lowLevelDict objectForKey:@"numberOfSteps"] integerValue] >= HIGH_LEVEL_MIN_STEP_COUNT) {
                    //NSLog(@"high level %@ - %@ => %lu", [lowLevelDict objectForKey:@"start"], [lowLevelDict objectForKey:@"end"], [[lowLevelDict objectForKey:@"numberOfSteps"] integerValue]);
                    [ranges addObjectsFromArray:[self getDateRangesWithStartDate:_startDate EndDate:_endDate TimeInterval:HIGH_LEVEL_TIME_INTERVAL]];
                } else {
                    //NSLog(@"low level %@ - %@ => %lu", [lowLevelDict objectForKey:@"start"], [lowLevelDict objectForKey:@"end"], [[lowLevelDict objectForKey:@"numberOfSteps"] integerValue]);
                    [ranges addObject:@{@"start": _startDate, @"end": _endDate, @"summarized": @1 }];
                }
            }
            completionBlock((NSArray*)ranges);
        }];
    }
    
}


-(void)queryDataWithStartDate:(NSDate*)startDate EndDate:(NSDate*)endDate TimeInterval:(NSTimeInterval)interval Completion:(void (^)(NSArray*stepData))completionBlock
{
    NSArray *dateRanges = [self getDateRangesWithStartDate:startDate EndDate:endDate TimeInterval:interval];
    NSMutableArray *values = [NSMutableArray array];
    
    for (int i = 0; i < [dateRanges count]; i++) {
        NSMutableDictionary *range = [NSMutableDictionary dictionaryWithDictionary:[dateRanges objectAtIndex:i]];
        
        [self.pedometer queryPedometerDataFromDate:range[@"start"] toDate:range[@"end"] withHandler:^(CMPedometerData *pedometerData, NSError *error) {
            NSNumber *numberOfSteps = [CMPedometer isStepCountingAvailable] && pedometerData.numberOfSteps ? pedometerData.numberOfSteps : [NSNumber numberWithInt:0];
            [range setObject:numberOfSteps forKey:@"numberOfSteps"];
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
