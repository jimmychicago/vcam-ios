#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#import <objc/message.h>

#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

#import "image_utils.h"

static int vcamLogFD = -1;

static void VCamFileLog(const char *text) {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        vcamLogFD = open(
            "/var/mobile/vcam-debug.log",
            O_CREAT | O_WRONLY | O_APPEND,
            0644
        );
    });

    if (vcamLogFD < 0 || text == NULL) {
        return;
    }

    write(vcamLogFD, text, strlen(text));
}

%hook BWNodeOutput

- (void)emitSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    unsigned int mediaType =
        ((unsigned int (*)(id, SEL))objc_msgSend)(
            self,
            sel_registerName("mediaType")
        );

    if (mediaType != 'vide') {
        %orig(sampleBuffer);
        return;
    }

    CVPixelBufferRef originalImageBuffer =
        CMSampleBufferGetImageBuffer(sampleBuffer);

    if (originalImageBuffer == NULL) {
        VCamFileLog("[VCAM-DEBUG] imageBuffer=NULL\n");

        %orig(sampleBuffer);
        return;
    }

    // ===== LOGGER =====
    static unsigned long debugCounter = 0;
    debugCounter++;

    if (debugCounter % 30 == 0) {
        OSType format =
            CVPixelBufferGetPixelFormatType(originalImageBuffer);

        size_t width =
            CVPixelBufferGetWidth(originalImageBuffer);

        size_t height =
            CVPixelBufferGetHeight(originalImageBuffer);

        size_t planes =
            CVPixelBufferGetPlaneCount(originalImageBuffer);

        char fmt[5];

        fmt[0] = (format >> 24) & 0xFF;
        fmt[1] = (format >> 16) & 0xFF;
        fmt[2] = (format >> 8) & 0xFF;
        fmt[3] = format & 0xFF;
        fmt[4] = '\0';

        char line[512];

        snprintf(
            line,
            sizeof(line),
            "[VCAM-DEBUG] ptr=%p media=%c%c%c%c format=%s 0x%08x size=%zux%zu planes=%zu\n",
            self,
            (mediaType >> 24) & 0xFF,
            (mediaType >> 16) & 0xFF,
            (mediaType >> 8) & 0xFF,
            mediaType & 0xFF,
            fmt,
            (unsigned int)format,
            width,
            height,
            planes
        );

        VCamFileLog(line);
    }
    // ===== LOGGER END =====

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loadReplacementMedia();
    });

    @try {
        CVPixelBufferLockBaseAddress(originalImageBuffer, 0);

        drawReplacementOntoBuffer(originalImageBuffer);
    }
    @finally {
        CVPixelBufferUnlockBaseAddress(originalImageBuffer, 0);
    }

    %orig(sampleBuffer);
}

%end
