//
//  HXWebView.h
//  ParentDemo
//
//  Created by James on 2019/6/14.
//  Copyright © 2019 DaHuanXiong. All rights reserved.
//

#import <WebKit/WebKit.h>

typedef void(^WebInvokeNativeHandler)(WKScriptMessage * _Nonnull message);

NS_ASSUME_NONNULL_BEGIN

//@warning: whem remove from superView all services supplied by self  will be done even you readd it to a view
@interface HXWebView : WKWebView
<
    WKUIDelegate,
    WKNavigationDelegate
>

/**
 default: nil
 */
@property (nonatomic, strong, nullable) UIView  *hudView;

/**
 default: nil
 */
@property (nonatomic, strong, nullable) UIView  *failView;


@property (nonatomic, strong, nullable) UIProgressView  *progressView;

@property (nonatomic, assign, readonly) BOOL   loadSuccessFlag;

//warning reference circular
@property (nonatomic, copy) void (^LoadFinishHandler)(BOOL success);


- (void)loadURLStr:(NSString *)URLStr;

//warning : reference circular
- (void)registMethodInvokedByWeb:(NSString *)methodName
       nativeHandler:(WebInvokeNativeHandler)nativeHandler;

- (void)unregistMethodInvokedByWeb:(NSString *)methodName;

- (void)unregistAllMethodInvokedByWeb;

- (void)invokeWebMethod:(NSString *)jsString completionHandler:(void(^)(id _Nullable result, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
