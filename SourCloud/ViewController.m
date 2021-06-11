//
//  ViewController.m
//  SourCloud
//
//  Created by Barry on 2021/1/26.
//  Copyright © 2021 Barry. All rights reserved.
//

#import "ViewController.h"
#import "HTMLParser.h"
#import <UserNotifications/UserNotifications.h>
#import <WebKit/WebKit.h>

typedef NS_ENUM(NSUInteger, HTTPMethod) {
    HTTPMethodGET,
    HTTPMethodPOST
};

static NSString * const kLoginURLString = @"";
static NSString * const kOnlineSwipeURLString = @"";
static NSString * const kUsernameKey = @"name_preference";
static NSString * const kPasswordKey = @"password_preference";

@interface ViewController ()<WKUIDelegate>

@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) IBOutlet WKWebView *webView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.username.length == 0 || self.password.length == 0) {
        NSURL *URL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        [[UIApplication sharedApplication] openURL:URL options:@{} completionHandler:^(BOOL success) {
            exit(0);
        }];
        return;
    }
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options = UNAuthorizationOptionSound | UNAuthorizationOptionAlert;
    [center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
        // Do nothing
    }];
    
    self.webView.UIDelegate = self;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:config];
    
    [self loadLoginWithCompletionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *form = [self formWithData:data];
        [self loginWithForm:form completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSArray<NSHTTPCookie *> *cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage].cookies;
            for (NSHTTPCookie *cookie in cookies) {
                [self.webView.configuration.websiteDataStore.httpCookieStore setCookie:cookie completionHandler:nil];
            }
            
            NSURL *URL = [NSURL URLWithString:kOnlineSwipeURLString];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
                [self.webView loadRequest:request];
            }];
        }];
    }];
}

- (void)loadLoginWithCompletionHandler:(void (^)(NSData *data, NSURLResponse * response, NSError * error))completionHandler {
    NSMutableURLRequest *request = [self requestWithMethod:HTTPMethodGET URLString:kLoginURLString];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:completionHandler];
    [task resume];
}

- (void)loginWithForm:(NSDictionary *)form completionHandler:(void (^)(NSData *data, NSURLResponse * response, NSError * error))completionHandler {
    NSMutableArray *queryItems = [NSMutableArray array];
    [form enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL * stop) {
        NSString *value = [self percentEscapedQueryStringWithURLString:obj encoding:NSASCIIStringEncoding];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:key value:value]];
    }];
    NSURLComponents *components = [NSURLComponents componentsWithString:@""];
    components.queryItems = queryItems;
    NSString *query = components.query;
    
    NSMutableURLRequest *request = [self requestWithMethod:HTTPMethodPOST URLString:kLoginURLString];
    request.HTTPBody = [query dataUsingEncoding:NSASCIIStringEncoding];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:completionHandler];
    [task resume];
}

- (NSString *)username {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kUsernameKey];
}

- (NSString *)password {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kPasswordKey];
}

- (NSString *)percentEscapedQueryStringWithURLString:(NSString *)urlString encoding:(NSStringEncoding)encoding {
    CFStringRef encodedCFString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef) urlString, nil, CFSTR("?!@#$^&%*+,:;='\"`<>()[]{}/\\| "), kCFStringEncodingUTF8);
    return [[NSString alloc] initWithString:(__bridge_transfer NSString*) encodedCFString];
}

- (NSString *)methodStringWithValue:(HTTPMethod)method {
    switch (method) {
        case HTTPMethodGET:
            return @"GET";
        case HTTPMethodPOST:
            return @"POST";
    }
}

- (NSMutableURLRequest *)requestWithMethod:(HTTPMethod)method URLString:(NSString *)URLString {
    NSURL *URL = [NSURL URLWithString:URLString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = [self methodStringWithValue:method];
    request.allHTTPHeaderFields = @{@"User-Agent" : @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36"};
    return request;
}

- (NSDictionary *)formWithData:(NSData *)data {
    HTMLParser *parser = [[HTMLParser alloc] initWithData:data error:nil];
    NSArray *inputNodes = [parser.body findChildTags:@"input"];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (HTMLNode *node in inputNodes) {
        NSString *name = [node getAttributeNamed:@"name"];
        NSString *value = [node getAttributeNamed:@"value"];
        if (name.length > 0 && value.length > 0) {
            dictionary[name] = value;
        }
    }
    dictionary[@"edtUserID"] = self.username;
    dictionary[@"edtPassword"] = self.password;
    return dictionary.copy;
}

- (NSString *)parseData:(NSData *)data {
    HTMLParser *parser = [[HTMLParser alloc] initWithData:data error:nil];
    NSArray *inputNodes = [parser.body findChildTags:@"input"];
    NSMutableString *text = [NSMutableString string];
    for (HTMLNode *node in inputNodes) {
        NSString *name = [node getAttributeNamed:@"name"];
        NSString *value = [node getAttributeNamed:@"value"];
        if (name.length > 0 && value.length > 0) {
            [text appendFormat:@"%@ : %@\n", name, value];
        }
    }
    return text.copy;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] performSelector:@selector(suspend)];
        completionHandler();
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (NSDate *)scheduleClockOutNotificationIfNeededWithMessage:(NSString *)message {
    if (![message containsString:@"Clock-inSwipe success"]) {
        return nil;
    }
    NSTimeInterval timeInterval = 60 * 60 * 9;
    [self scheduleClockOutNotificationWithTimeInterval:timeInterval];
    return [NSDate dateWithTimeIntervalSinceNow:timeInterval];
}

- (void)scheduleClockOutNotificationWithTimeInterval:(NSTimeInterval)timeInterval {
    UNNotificationRequest *request = ({
        UNMutableNotificationContent *content = ({
            content = [[UNMutableNotificationContent alloc] init];
            content.body = @"Clock Out Time!";
            content.sound = UNNotificationSound.defaultSound;
            content;
        });
        
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:timeInterval repeats:NO];
        request = [UNNotificationRequest requestWithIdentifier:@"identifier"
                                                       content:content
                                                       trigger:trigger];
        request;
    });
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
}

#pragma mark - WKUIDelegate

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    NSArray *messages = [message componentsSeparatedByString:@"\n"];
    NSString *title = messages.firstObject;
    NSMutableArray *details = [NSMutableArray array];
    if (messages.count > 0) {
        NSRange range = NSMakeRange(1, messages.count - 1);
        [details addObjectsFromArray:[messages subarrayWithRange:range]];
    }
    
    NSDate *scheduledDate = [self scheduleClockOutNotificationIfNeededWithMessage:message];
    if (scheduledDate != nil) {
        NSString *time = [NSDateFormatter localizedStringFromDate:scheduledDate
                                                        dateStyle:NSDateFormatterNoStyle
                                                        timeStyle:NSDateFormatterMediumStyle];
        NSString *description = [NSString stringWithFormat:@"Reminder scheduled at %@", time];
        [details addObject:description];
    }
    NSString *detail = [details componentsJoinedByString:@"\n"];
    [self showAlertWithTitle:title message:detail completionHandler:completionHandler];
}

@end
