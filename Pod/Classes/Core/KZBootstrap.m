@import Foundation;
@import ObjectiveC.runtime;
@import UIKit.UIApplication;

#import <KZAsserts/KZAsserts.h>
#import "KZBootstrap.h"

static NSString *const kLastEnvKey = @"KZBCurrentEnv";

@implementation KZBootstrap

+ (void)ready
{

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkEnvironmentOverride) name:UIApplicationWillEnterForegroundNotification object:nil];
    [self environmentVariables];
    [self checkEnvironmentOverride];
}

+ (NSString *)shortVersionString
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (NSString *)gitBranch
{
    NSArray *components = [self.versionString componentsSeparatedByString:@"-"];
    return components.count == 2 ? components[1] : nil;
}

+ (NSInteger)buildNumber
{
    NSArray *components = [self.versionString componentsSeparatedByString:@"-"];
    return components.count >= 1 ? [(NSString *)components[0] integerValue] : 0;
}

+ (NSString *)versionString
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
}

+ (void)checkEnvironmentOverride
{
    NSString *envOverride = self.environmentOverride;
    
    if (envOverride && ![self.lastEnvironment isEqualToString:envOverride]) {
        self.lastEnvironment = envOverride;
    }
    else if (envOverride && [envOverride isEqualToString:@"CUSTOM"]) {
        if (![[self clearDict:[self currentCustomValues]] isEqualToDictionary:[self clearDict:[self lastCustomValues]]]) {
            self.onCurrentEnvironmentChanged(envOverride, [self lastEnvironment], [self currentCustomValues],[self lastCustomValues]);
            [self updateLastCustomValues];
        }
    }
}

+(NSDictionary*)lastCustomValues{
    return [self _userDefultsValuesWithPrefix:@"KZBCustom.Last."];
}

+(void)updateLastCustomValues{
    NSDictionary* currentCustomValues = [self currentCustomValues];
    for (NSString* key in [currentCustomValues allKeys]) {
        NSString* lastKey = [key stringByReplacingOccurrencesOfString:@"KZBCustom.Current." withString:@"KZBCustom.Last."];
        [[NSUserDefaults standardUserDefaults] setObject:currentCustomValues[key] forKey:lastKey];
    }
}

+(NSDictionary*)currentCustomValues{
    return [self _userDefultsValuesWithPrefix:@"KZBCustom.Current."];
}

+(NSDictionary*)clearDict:(NSDictionary*)dict{
    NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
    NSArray* keys = [dict allKeys];
    for (NSString* key in keys) {
        NSString* clearKey;
        if([key hasPrefix:@"KZBCustom.Current."]){
            clearKey = [key stringByReplacingOccurrencesOfString:@"KZBCustom.Current." withString:@""];
        }
        else if([key hasPrefix:@"KZBCustom.Last."]){
            clearKey = [key stringByReplacingOccurrencesOfString:@"KZBCustom.Last." withString:@""];
        }
        if (clearKey) {
            result[clearKey] = dict[key];
        }
    }
    return result;
}

+(NSDictionary*)_userDefultsValuesWithPrefix:(NSString*)prefix{
    NSMutableDictionary* dict = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] mutableCopy];
    NSArray* keys = [dict allKeys];
    NSArray* filteredArray = [keys objectsAtIndexes:[keys indexesOfObjectsPassingTest:^BOOL(NSString* obj, NSUInteger idx, BOOL *stop) {
        return [obj hasPrefix:prefix];
    }]];
    NSMutableDictionary* filteredDict = [[NSMutableDictionary alloc] init];
    for (NSString* key in filteredArray) {
        filteredDict[key] = dict[key];
    }
    return filteredDict;
}

+ (id)envVariableForKey:(NSString *)key
{
    id value = self.environmentVariables[key][self.lastEnvironment];
    if ([self.lastEnvironment isEqualToString:@"CUSTOM"]) {
        value = [[NSUserDefaults standardUserDefaults] objectForKey:[@"KZBCustom.Current." stringByAppendingString:key]];
        if (!value){
            value = @"";
        }
    }
    AssertTrueOrReturnNil(value);
    return value;
}

+ (NSArray *)environments
{
    static dispatch_once_t onceToken;
    static NSArray *listOfEnvironments;
    
    dispatch_once(&onceToken, ^{
        NSDictionary *propertyList = [self environment];
        
        NSString *envKey = @"KZBEnvironments";
        listOfEnvironments = propertyList[envKey];
    });
    
    return listOfEnvironments;
}

+ (NSDictionary *)environmentVariables
{
    static dispatch_once_t onceToken;
    static NSDictionary *environmentVariables;
    
    dispatch_once(&onceToken, ^{
        NSMutableDictionary *propertyList = [[self environment] mutableCopy];
        
        NSString *envKey = @"KZBEnvironments";
        [propertyList removeObjectForKey:envKey];
        environmentVariables = [propertyList copy];
    });
    
    return environmentVariables;
}

+ (NSDictionary *)environment
{
    static dispatch_once_t onceToken;
    static NSDictionary *environment;
    
    dispatch_once(&onceToken, ^{
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"KZBEnvironments" withExtension:@"plist"];
        AssertTrueOrReturn(url);
        NSError *error = nil;
        NSMutableDictionary *propertyList = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:url] options:NSPropertyListMutableContainers format:NULL error:&error];
        AssertTrueOrReturn(propertyList);
        
        environment = [propertyList copy];
        
        NSString *envKey = @"KZBEnvironments";
        NSArray *listOfEnvironments = [propertyList valueForKey:envKey];
        [propertyList removeObjectForKey:envKey];
        [self ensureValidityOfEnvironmentVariables:propertyList forEnvList:listOfEnvironments];
    });
    
    return environment;
}

+ (void)ensureValidityOfEnvironmentVariables:(NSMutableDictionary *)dictionary forEnvList:(NSArray *)list
{
    __block BOOL environmentVariablesAreValid = YES;
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *configurations, BOOL *stop) {
        //! format check.
        if (![key isKindOfClass:NSString.class] || ![configurations isKindOfClass:NSDictionary.class]) {
            environmentVariablesAreValid = NO;
            *stop = YES;
            return;
        }
        
        //! make sure all env have set variable
        NSMutableArray *listOfEnvSetup = [list mutableCopy];
        [configurations.allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
            if (![key isKindOfClass:NSString.class]) {
                environmentVariablesAreValid = NO;
                *stop = YES;
            }
            
            [listOfEnvSetup removeObject:key];
        }];
        
        if (listOfEnvSetup.count != 0) {
            environmentVariablesAreValid = NO;
        }
        
        if (!environmentVariablesAreValid) {
            *stop = YES;
        }
    }];
    
    AssertTrueOrReturn(environmentVariablesAreValid);
}

+ (NSString *)environmentOverride
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"KZBEnvOverride"];
}

static const void *kEnvKey = &kEnvKey;
static const void *kDefaultBuildEnvKey = &kDefaultBuildEnvKey;

+ (void)setDefaultBuildEnvironment:(NSString*)defaultBuildEnv
{
    objc_setAssociatedObject(self, kDefaultBuildEnvKey, defaultBuildEnv, OBJC_ASSOCIATION_COPY);
}

+ (NSString*)defaultBuildEnvironment
{
    return objc_getAssociatedObject(self, kDefaultBuildEnvKey);
}

+ (NSString *)lastEnvironment
{
    NSString *env = objc_getAssociatedObject(self, kEnvKey);
    if (!env) {
        NSString *defaultBuildEnv = self.defaultBuildEnvironment;
        AssertTrueOrReturnNil(defaultBuildEnv);
        env = self.previousEnvironment ?: defaultBuildEnv;
        objc_setAssociatedObject(self, kEnvKey, env, OBJC_ASSOCIATION_COPY);
        return env;
    }
    return env;
}

+ (void)setLastEnvironment:(NSString *)environment
{
    NSString *oldEnv = self.lastEnvironment;
    objc_setAssociatedObject(self, kEnvKey, environment, OBJC_ASSOCIATION_COPY);
    if (environment && [environment isEqualToString:@"CUSTOM"]) {
        self.onCurrentEnvironmentChanged(environment, oldEnv, [self currentCustomValues],[self lastCustomValues]);
        [self updateLastCustomValues];
        
    }

    else if (oldEnv && self.onCurrentEnvironmentChanged && ![oldEnv isEqualToString:environment]) {
        self.onCurrentEnvironmentChanged(environment, oldEnv, nil, nil);
    }
    
    //! persist current env between versions
    [[NSUserDefaults standardUserDefaults] setObject:environment forKey:kLastEnvKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


+ (NSString *)previousEnvironment
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kLastEnvKey];
}

static const void *kOnCurrentEnvChangedKey = &kOnCurrentEnvChangedKey;

+ (void (^)(NSString *, NSString *, NSDictionary*, NSDictionary*))onCurrentEnvironmentChanged
{
    return objc_getAssociatedObject(self, kOnCurrentEnvChangedKey);
}

+ (void)setOnCurrentEnvironmentChanged:(void (^)(NSString *, NSString *, NSDictionary*, NSDictionary*))block
{
    objc_setAssociatedObject(self, kOnCurrentEnvChangedKey, block, OBJC_ASSOCIATION_COPY);
}

@end
