//
// --------------------------------------------------------------------------
// LogitechCIDActivator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Miguel Angelo in 2026
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------

#import "LogitechCIDActivator.h"
#import <IOKit/hid/IOHIDLib.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>
#import "SharedUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "DeviceManager.h"

#define kLogitechVID    0x046D
#define kHIDPP_Long     0x11
#define kHIDPP_Device   0xFF
#define kFeat_ReprogV4  0x1B04

/// SetCidReporting flags — Solaar hidpp20.py "valid bit" pattern:
///   each flag bit has a corresponding valid bit = flag << 1
///   0x03 = divert=1 (bit0) + divert_valid=1 (bit1)
#define kDivertFlags    0x03

/// TIDs of controls that already report natively — must NOT be diverted
///   0x0038=left, 0x0039=right, 0x003A=middle, 0x003C=back, 0x003E=forward
static const uint16_t kNativeTIDs[] = { 0x0038, 0x0039, 0x003A, 0x003C, 0x003E };

/// CGEvent button numbers are 0-based. 5 = MMF "button 6" (first above L/R/M/Back/Fwd)
#define kFirstCGButton  6

typedef struct {
    IOHIDDeviceRef  device;
    uint8_t         reportBuf[64];
    uint16_t        cidMap[32];
    int             cidCount;
    uint16_t        pressedCIDs[32];
    int             pressedCount;
    CFAbsoluteTime  lastReportTime;
    BOOL            needsReactivation;
} MFCIDDeviceState;

static uint8_t sResp[20];
static BOOL    sGotResp = NO;

/// Forward declarations
static int activateDevice(IOHIDDeviceRef dev, MFCIDDeviceState *s);
static IOReturn sendAndWait(IOHIDDeviceRef dev, uint8_t *pkt);

static BOOL isNativeTID(uint16_t tid) {
    for (int i = 0; i < 5; i++) if (kNativeTIDs[i] == tid) return YES;
    return NO;
}

static int buttonForCID(MFCIDDeviceState *s, uint16_t cid) {
    for (int i = 0; i < s->cidCount; i++)
        if (s->cidMap[i] == cid) return kFirstCGButton + i;
    if (s->cidCount < 32) { s->cidMap[s->cidCount++] = cid; return kFirstCGButton + s->cidCount - 1; }
    return kFirstCGButton;
}

static void injectButton(MFCIDDeviceState *s, uint16_t cid, BOOL down) {
    int btn = buttonForCID(s, cid);
    Device *device = [DeviceManager attachedDeviceWithIOHIDDevice: s->device];
    if (!device) device = [Device strangeDevice];
    CGEventRef event = CGEventCreate(NULL);
    [Buttons handleInputWithDevice: device button: @(btn) downNotUp: down event: event];
    CFRelease(event);
}

static void inputReportCallback(void *ctx, IOReturn result, void *sender,
                                IOHIDReportType type, uint32_t reportID,
                                uint8_t *report, CFIndex len) {
    /// Accept both short (0x10, 7 bytes) and long (0x11, 20 bytes) HID++ reports
    /// Short reports come from Unifying receivers, long from Bolt/BT
    if (len < 5) return;
    if (report[0] != kHIDPP_Long && report[0] != 0x10) return;
    MFCIDDeviceState *s = (MFCIDDeviceState *)ctx;
    
    /// Detect device reconnection: if >3 seconds since last report, re-activate diversion
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (s->lastReportTime > 0 && (now - s->lastReportTime) > 3.0) {
        s->needsReactivation = YES;
    }
    s->lastReportTime = now;
    
    /// Handle reactivation on main queue (sendAndWait needs runloop)
    if (s->needsReactivation) {
        s->needsReactivation = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            int diverted = activateDevice(s->device, s);
            DDLogInfo(@"LogitechCIDActivator: re-activated after reconnection (%d CIDs)", diverted);
        });
        return; /// Skip this report — it's likely stale
    }
    
    if (report[3] != 0x00) {
        memcpy(sResp, report, len < 20 ? (size_t)len : 20);
        sGotResp = YES;
        return;
    }
    
    /// CID bytes at offset 4,5 — format: [reportID, deviceIdx, featureIdx, funcId, CID_high, CID_low, ...]
    if (len < 6) return;
    uint16_t cid = ((uint16_t)report[4] << 8) | report[5];
    if (cid == 0) {
        for (int i = 0; i < s->pressedCount; i++) injectButton(s, s->pressedCIDs[i], NO);
        s->pressedCount = 0;
    } else {
        for (int i = 0; i < s->pressedCount; i++) if (s->pressedCIDs[i] == cid) return;
        injectButton(s, cid, YES);
        if (s->pressedCount < 32) s->pressedCIDs[s->pressedCount++] = cid;
    }
}

static IOReturn sendAndWait(IOHIDDeviceRef dev, uint8_t *pkt) {
    sGotResp = NO;
    /// Determine packet size from report ID: 0x10 = short (7 bytes), 0x11 = long (20 bytes)
    CFIndex pktLen = (pkt[0] == 0x10) ? 7 : 20;
    IOReturn r = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, pkt[0], pkt, pktLen);
    DDLogDebug(@"LogitechCIDActivator: sendAndWait reportID=0x%02X len=%ld result=%d", pkt[0], (long)pktLen, r);
    if (r != kIOReturnSuccess) return r;
    for (int i = 0; i < 100 && !sGotResp; i++) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
    if (!sGotResp) return kIOReturnTimeout;
    if (sResp[2] == 0xFF) return kIOReturnError;
    return kIOReturnSuccess;
}

static int activateDevice(IOHIDDeviceRef dev, MFCIDDeviceState *s) {
    uint8_t pkt[20];

    DDLogInfo(@"LogitechCIDActivator: activateDevice starting...");
    
    /// Determine device index — 0xFF for direct BT, 0x01 for first device on Unifying receiver
    NSNumber *usagePage = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDPrimaryUsagePageKey));
    BOOL isReceiver = (usagePage.integerValue == 0xFF00 || usagePage.integerValue == 0x00FF);
    uint8_t deviceIdx = isReceiver ? 0x01 : kHIDPP_Device;
    
    DDLogInfo(@"LogitechCIDActivator: isReceiver=%d deviceIdx=0x%02X", isReceiver, deviceIdx);
    
    /// 1. GetFeature(0x1B04)
    memset(pkt, 0, 20);
    pkt[0]=kHIDPP_Long; pkt[1]=deviceIdx; pkt[2]=0x00; pkt[3]=0x0E;
    pkt[4]=(kFeat_ReprogV4>>8)&0xFF; pkt[5]=kFeat_ReprogV4&0xFF;
    IOReturn r1 = sendAndWait(dev, pkt);
    DDLogInfo(@"LogitechCIDActivator: GetFeature result=%d resp[4]=%d", r1, sResp[4]);
    if (r1 != kIOReturnSuccess || sResp[4] == 0) return 0;
    uint8_t feat = sResp[4];

    /// 2. GetCount
    memset(pkt, 0, 20);
    pkt[0]=kHIDPP_Long; pkt[1]=deviceIdx; pkt[2]=feat; pkt[3]=0x0E;
    if (sendAndWait(dev, pkt) != kIOReturnSuccess) return 0;
    int count = sResp[4];

    /// 3. GetCidInfo — collect divertable CIDs
    uint16_t todivert[32]; int ndiv = 0;
    for (int i = 0; i < count && ndiv < 32; i++) {
        memset(pkt, 0, 20);
        pkt[0]=kHIDPP_Long; pkt[1]=deviceIdx; pkt[2]=feat; pkt[3]=0x1E; pkt[4]=(uint8_t)i;
        if (sendAndWait(dev, pkt) != kIOReturnSuccess) continue;
        uint16_t cid = ((uint16_t)sResp[4]<<8)|sResp[5];
        uint16_t tid = ((uint16_t)sResp[6]<<8)|sResp[7];
        uint8_t flags = sResp[8];
        if ((flags & (1<<4)) && !isNativeTID(tid)) todivert[ndiv++] = cid;
    }

    /// 4. Pre-register button mapping for stable numbering
    for (int i = 0; i < ndiv; i++) buttonForCID(s, todivert[i]);

    /// 5. SetCidReporting — divert
    int diverted = 0;
    for (int i = 0; i < ndiv; i++) {
        memset(pkt, 0, 20);
        pkt[0]=kHIDPP_Long; pkt[1]=deviceIdx; pkt[2]=feat; pkt[3]=0x3E;
        pkt[4]=(todivert[i]>>8)&0xFF; pkt[5]=todivert[i]&0xFF; pkt[6]=kDivertFlags;
        if (sendAndWait(dev, pkt) == kIOReturnSuccess) diverted++;
    }
    DDLogInfo(@"LogitechCIDActivator: diverted %d of %d CIDs (count=%d)", diverted, ndiv, count);
    return diverted;
}

@interface LogitechCIDActivator ()
@property (nonatomic) NSMutableArray *states;
@property (nonatomic) NSTimer *reactivateTimer;
@end

@implementation LogitechCIDActivator

+ (instancetype)shared {
    static LogitechCIDActivator *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [self new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _states = [NSMutableArray array];
        /// Re-activate on system wake — firmware clears divert state on sleep
        [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver: self
               selector: @selector(reactivateAll)
                   name: NSWorkspaceDidWakeNotification
                 object: nil];
        /// Periodic safety net — covers firmware timeout and missed reconnections
        _reactivateTimer = [NSTimer scheduledTimerWithTimeInterval: 30
                                                           target: self
                                                         selector: @selector(reactivateAll)
                                                         userInfo: nil
                                                          repeats: YES];
    }
    return self;
}

- (void)reactivateAll {
    for (NSValue *v in _states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        activateDevice(s->device, s);
    }
    DDLogDebug(@"LogitechCIDActivator: re-activated %lu device(s)", (unsigned long)_states.count);
}

- (void)handleDeviceAttached: (IOHIDDeviceRef)device {
    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    if (vid.integerValue != kLogitechVID) return;
    
    /// Check if we already have this device (reconnection without remove event)
    for (NSValue *v in _states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        if (s->device == device) {
            int diverted = activateDevice(device, s);
            DDLogInfo(@"LogitechCIDActivator: re-activated existing device (%d CIDs)", diverted);
            return;
        }
    }
    
    /// For Unifying receivers: only open the raw HID++ interface (usage page 0xFF00)
    /// Skip keyboard (usage page 0x01, usage 0x06) and mouse (usage page 0x01, usage 0x02) interfaces
    NSNumber *usagePage = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDPrimaryUsagePageKey));
    NSNumber *usage = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDPrimaryUsageKey));
    NSNumber *pid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    NSString *product = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    
    DDLogInfo(@"LogitechCIDActivator: device attached — product='%@' pid=0x%04lX usagePage=0x%04lX usage=0x%04lX",
              product, (long)pid.integerValue, (long)usagePage.integerValue, (long)usage.integerValue);
    
    /// Accept: BT mice (usage page 1, usage 2) OR raw HID++ interface (usage page 0xFF00)
    /// The raw interface is needed for Unifying receivers
    BOOL isMouse = (usagePage.integerValue == 0x01 && usage.integerValue == 0x02);
    BOOL isRawHIDPP = (usagePage.integerValue == 0xFF00 || usagePage.integerValue == 0x00FF);
    
    if (!isMouse && !isRawHIDPP) {
        DDLogInfo(@"LogitechCIDActivator: skipping non-mouse/non-raw interface");
        return;
    }
    
    /// For USB receivers (raw HID++ interface), try seize to get exclusive access
    /// For BT devices, use normal open (seize breaks them)
    NSNumber *openUsagePage = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDPrimaryUsagePageKey));
    BOOL isRawInterface = (openUsagePage.integerValue == 0xFF00);
    
    IOReturn openResult;
    if (isRawInterface) {
        openResult = IOHIDDeviceOpen(device, kIOHIDOptionsTypeSeizeDevice);
        if (openResult != kIOReturnSuccess) {
            openResult = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
        }
    } else {
        openResult = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    }
    
    if (openResult != kIOReturnSuccess) {
        NSLog(@"LogitechCIDActivator: ⚠️ Could not open device");
        return;
    }

    MFCIDDeviceState *s = calloc(1, sizeof(MFCIDDeviceState));
    s->device = device;
    IOHIDDeviceRegisterInputReportCallback(device, s->reportBuf, sizeof(s->reportBuf), inputReportCallback, s);
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);

    int diverted = activateDevice(device, s);
    if (diverted > 0) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        DDLogInfo(@"LogitechCIDActivator: diverted %d CIDs on '%@'", diverted, name);
        [_states addObject: [NSValue valueWithPointer: s]];
    } else {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
        free(s);
    }
}

- (void)handleDeviceRemoved: (IOHIDDeviceRef)device {
    NSValue *found = nil;
    for (NSValue *v in _states) {
        if (((MFCIDDeviceState *)v.pointerValue)->device == device) { found = v; break; }
    }
    if (!found) return;
    MFCIDDeviceState *s = (MFCIDDeviceState *)found.pointerValue;
    for (int i = 0; i < s->pressedCount; i++) injectButton(s, s->pressedCIDs[i], NO);
    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
    free(s);
    [_states removeObject: found];
}

@end
