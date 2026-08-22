%hook BWNodeOutput

- (void)emitSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    unsigned int mediaType = ((unsigned int (*)(id, SEL))objc_msgSend)(self, sel_registerName("mediaType"));

    if (mediaType != 'vide') {
        %orig(sampleBuffer);
        return;
    }

    CVPixelBufferRef originalImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    if (originalImageBuffer == NULL) {
        NSLog(@"[VCAM-DEBUG] imageBuffer=NULL node=%@", NSStringFromClass([self class]));
        %orig(sampleBuffer);
        return;
    }

    // ===== LOGGER =====
    static unsigned long debugCounter = 0;
    debugCounter++;

    if (debugCounter % 30 == 0) {
        OSType format = CVPixelBufferGetPixelFormatType(originalImageBuffer);
        size_t width = CVPixelBufferGetWidth(originalImageBuffer);
        size_t height = CVPixelBufferGetHeight(originalImageBuffer);
        size_t planes = CVPixelBufferGetPlaneCount(originalImageBuffer);

        char fmt[5];
        fmt[0] = (format >> 24) & 0xFF;
        fmt[1] = (format >> 16) & 0xFF;
        fmt[2] = (format >> 8) & 0xFF;
        fmt[3] = format & 0xFF;
        fmt[4] = '\0';

        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

        NSLog(
            @"[VCAM-DEBUG] node=%@ ptr=%p media=%c%c%c%c format=%s 0x%08x size=%zux%zu planes=%zu pts=%lld/%d",
            NSStringFromClass([self class]),
            self,
            (mediaType >> 24) & 0xFF,
            (mediaType >> 16) & 0xFF,
            (mediaType >> 8) & 0xFF,
            mediaType & 0xFF,
            fmt,
            (unsigned int)format,
            width,
            height,
            planes,
            pts.value,
            pts.timescale
        );
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
