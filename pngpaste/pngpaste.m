/*
 * pngpaste
 */

#import "pngpaste.h"

void
usage ()
{
    fprintf(stderr,
        "Usage: %s [OPTIONS] <dest.png>\n"
        "\t-v\t" "Version" "\n"
        "\t-a\t" "Assert pasteboard" "\n"
        "\t-h,-?\t" "This usage" "\n",
        APP_NAME);
}

void
fatal (const char *msg)
{
    if (msg != NULL) {
        fprintf(stderr, "%s: %s\n", APP_NAME, msg);
    }
}

void
version ()
{
    fprintf(stderr, "%s %s\n", APP_NAME, APP_VERSION);
}

ImageType
extractImageType (NSImage *image)
{
    ImageType imageType = ImageTypeNone;
    if (image != nil) {
        NSArray *reps = [image representations];
        NSImageRep *rep = [reps lastObject];
        if ([rep isKindOfClass:[NSPDFImageRep class]]) {
            imageType = ImageTypePDF;
        } else if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            imageType = ImageTypeBitmap;
        }
    }
    return imageType;
}

NSData *
renderImageData (NSImage *image, NSBitmapImageFileType bitmapImageFileType)
{
    ImageType imageType = extractImageType(image);
    switch (imageType) {
    case ImageTypeBitmap:
        return renderFromBitmap(image, bitmapImageFileType);
        break;
    case ImageTypePDF:
        return renderFromPDF(image, bitmapImageFileType);
        break;
    case ImageTypeNone:
    default:
        return nil;
        break;
    }
}

NSData *
renderFromBitmap (NSImage *image, NSBitmapImageFileType bitmapImageFileType)
{
    NSArray *representations = [image representations];
    return [NSBitmapImageRep representationOfImageRepsInArray:representations
                                                    usingType:bitmapImageFileType
                                                   properties:@{}];
}

NSData *
renderFromPDF (NSImage *image, NSBitmapImageFileType bitmapImageFileType)
{
    NSPDFImageRep *pdfImageRep =
        (NSPDFImageRep *)[[image representations] lastObject];
    CGFloat factor = PDF_SCALE_FACTOR;
    NSRect bounds = NSMakeRect(
        0, 0,
        pdfImageRep.bounds.size.width * factor,
        pdfImageRep.bounds.size.height * factor);

    NSImage *genImage = [[NSImage alloc] initWithSize:bounds.size];
    [genImage lockFocus];
    [[NSColor whiteColor] set];
    NSRectFill(bounds);
    [pdfImageRep drawInRect:bounds];
    [genImage unlockFocus];

    NSData *genImageData = [genImage TIFFRepresentation];
    return [[NSBitmapImageRep imageRepWithData:genImageData]
                       representationUsingType:bitmapImageFileType
                                    properties:@{}];
}

/*
 * Returns NSBitmapImageFileType based off of filename extension
 */
NSBitmapImageFileType
getBitmapImageFileTypeFromFilename (NSString *filename)
{
    static NSDictionary *lookup;
    if (lookup == nil) {
        lookup = @{
            @"gif": [NSNumber numberWithInt:NSBitmapImageFileTypeGIF],
            @"jpeg": [NSNumber numberWithInt:NSBitmapImageFileTypeJPEG],
            @"jpg": [NSNumber numberWithInt:NSBitmapImageFileTypeJPEG],
            @"png": [NSNumber numberWithInt:NSBitmapImageFileTypePNG],
            @"tif": [NSNumber numberWithInt:NSBitmapImageFileTypeTIFF],
            @"tiff": [NSNumber numberWithInt:NSBitmapImageFileTypeTIFF],
        };
    }
    NSBitmapImageFileType bitmapImageFileType = NSBitmapImageFileTypePNG;
    if (filename != nil) {
        NSArray *words = [filename componentsSeparatedByString:@"."];
        NSUInteger len = [words count];
        if (len > 1) {
            NSString *extension = (NSString *)[words objectAtIndex:(len - 1)];
            NSString *lowercaseExtension = [extension lowercaseString];
            NSNumber *value = lookup[lowercaseExtension];
            if (value != nil) {
                bitmapImageFileType = [value unsignedIntegerValue];
            }
        }
    }
    return bitmapImageFileType;
}

/*
 * Returns NSData from Pasteboard Image if available; otherwise nil
 */
NSData *
getPasteboardImageData (NSPasteboard *pasteBoard, NSBitmapImageFileType bitmapImageFileType)
{
    NSImage *image = [[NSImage alloc] initWithPasteboard:pasteBoard];
    NSData *imageData = nil;

    if (image != nil) {
        imageData = renderImageData(image, bitmapImageFileType);
    }

    [image release];
    return imageData;
}

Parameters
parseArguments (int argc, char* const argv[])
{
    Parameters params;

    params.outputFile = nil;
    params.wantsVersion = NO;
    params.wantsUsage = NO;
    params.wantsStdout = NO;
    params.malformed = NO;
    params.wantAssert = NO;

    int ch;
    while ((ch = getopt(argc, argv, "vah?")) != -1) {
        switch (ch) {
        case 'v':
            params.wantsVersion = YES;
            return params;
            break;
        case 'a':
            params.wantAssert = YES;
            return params;
            break;
        case 'h':
        case '?':
            params.wantsUsage = YES;
            return params;
            break;
        default:
            params.malformed = YES;
            return params;
            break;
        }
    }

    if (argc < 2) {
        params.malformed = YES;
    } else if (!strcmp(argv[1],STDOUT_FILENAME)) {
        params.wantsStdout = YES;
    } else {
        params.outputFile =
            [[NSString alloc] initWithCString:argv[1]
                                     encoding:NSUTF8StringEncoding];
    }
    return params;
}

int
main (int argc, char * const argv[])
{
    Parameters params = parseArguments(argc, argv);
    BOOL canPaste = YES;
    if (params.malformed) {
        usage();
        return EXIT_FAILURE;
    } else if (params.wantsUsage) {
        usage();
        return EXIT_SUCCESS;
    } else if (params.wantsVersion) {
        version();
        return EXIT_SUCCESS;
    }

    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    if ([[pasteBoard types] containsObject:NSPasteboardTypeString]) {
        canPaste = NO;
    }
    if (params.wantAssert) {
        if (canPaste) {
            NSLog(@"Can be pasted!");
            return EXIT_SUCCESS;
        } else {
            NSLog(@"Cannot be pasted!");
            return EXIT_FAILURE;
        }
    } else {
        if (!canPaste) {
            fatal("No image data found on the clipboard, or could not convert!");
            return EXIT_FAILURE;
        }
        NSBitmapImageFileType bitmapImageFileType =
            getBitmapImageFileTypeFromFilename(params.outputFile);
        NSData *imageData = getPasteboardImageData(pasteBoard, bitmapImageFileType);
        int exitCode;

        if (imageData != nil) {
            if (params.wantsStdout) {
                NSFileHandle *stdout =
                    (NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput];
                [stdout writeData:imageData];
                exitCode = EXIT_SUCCESS;
            } else {
                if ([imageData writeToFile:params.outputFile atomically:YES]) {
                    exitCode = EXIT_SUCCESS;
                } else {
                    fatal("Could not write to file!");
                    exitCode = EXIT_FAILURE;
                }
            }
        } else {
            fatal("No image data found on the clipboard, or could not convert!");
            exitCode = EXIT_FAILURE;
        }

        return exitCode;
    }
}
