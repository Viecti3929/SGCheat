%hook UnityAppController

- (void)applicationDidFinishLaunching:(id)arg1 {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [SGMenu sharedMenu];
    });
}

%end
