const sharp = require('sharp');
const logger = require('./config/logger');

const SUPPORTED_FORMATS = ['jpeg', 'jpg', 'png', 'webp', 'gif', 'avif', 'tiff'];

function parseCompressionCommand(messageText) {
    if (!messageText) return null;
    
    const text = messageText.toLowerCase();
    if (!text.includes('compress')) return null;

    // Match "compress to X%" for quality reduction
    const qualityMatch = text.match(/compress\s+to\s+(\d+)\s*%/);
    if (qualityMatch) {
        const quality = parseInt(qualityMatch[1], 10);
        if (quality >= 1 && quality <= 100) {
            return { type: 'quality', value: quality };
        }
    }

    // Match "compress to Xp" for resolution (e.g., 720p, 1080p)
    const resolutionMatch = text.match(/compress\s+to\s+(\d+)\s*p\b/);
    if (resolutionMatch) {
        const height = parseInt(resolutionMatch[1], 10);
        if (height >= 1 && height <= 8640) {
            return { type: 'resolution', value: height };
        }
    }

    // Match "compress to X KB" or "compress to X MB" for target file size
    const sizeMatch = text.match(/compress\s+to\s+(\d+(?:\.\d+)?)\s*(kb|mb|gb)/);
    if (sizeMatch) {
        const size = parseFloat(sizeMatch[1]);
        const unit = sizeMatch[2];
        let targetBytes;
        switch (unit) {
            case 'kb': targetBytes = size * 1024; break;
            case 'mb': targetBytes = size * 1024 * 1024; break;
            case 'gb': targetBytes = size * 1024 * 1024 * 1024; break;
        }
        if (targetBytes >= 1024) {
            return { type: 'filesize', value: Math.floor(targetBytes) };
        }
    }

    // Generic "compress" without parameters - default to 80% quality
    if (/\bcompress\b/.test(text)) {
        return { type: 'quality', value: 80 };
    }

    return null;
}

function isImageSupported(mimeType, fileName) {
    if (mimeType && mimeType.startsWith('image/')) {
        const format = mimeType.split('/')[1].toLowerCase();
        if (SUPPORTED_FORMATS.includes(format)) return true;
    }
    
    if (fileName) {
        const ext = fileName.split('.').pop()?.toLowerCase();
        if (SUPPORTED_FORMATS.includes(ext)) return true;
    }
    
    return false;
}

async function compressImage(buffer, options, mimeType) {
    try {
        let image = sharp(buffer);
        const metadata = await image.metadata();
        
        if (!metadata.format || !SUPPORTED_FORMATS.includes(metadata.format)) {
            logger.warn('Unsupported image format for compression', { format: metadata.format });
            return { buffer, compressed: false };
        }

        const outputFormat = metadata.format === 'gif' ? 'gif' : (metadata.format === 'png' ? 'png' : 'jpeg');
        
        switch (options.type) {
            case 'quality':
                image = applyQualityCompression(image, options.value, outputFormat);
                break;
                
            case 'resolution':
                image = image.resize({ height: options.value, withoutEnlargement: true });
                image = applyQualityCompression(image, 85, outputFormat);
                break;
                
            case 'filesize':
                return await compressToTargetSize(buffer, options.value, metadata, outputFormat);
        }

        const outputBuffer = await image.toBuffer();
        
        logger.info('Image compressed', {
            type: options.type,
            value: options.value,
            originalSize: buffer.length,
            compressedSize: outputBuffer.length,
            reduction: `${Math.round((1 - outputBuffer.length / buffer.length) * 100)}%`
        });

        return { 
            buffer: outputBuffer, 
            compressed: true,
            mimeType: `image/${outputFormat}`
        };
    } catch (error) {
        logger.error('Compression failed', { error: error.message });
        return { buffer, compressed: false };
    }
}

function applyQualityCompression(image, quality, format) {
    switch (format) {
        case 'jpeg':
        case 'jpg':
            return image.jpeg({ quality });
        case 'png':
            return image.png({ quality });
        case 'webp':
            return image.webp({ quality });
        case 'avif':
            return image.avif({ quality });
        default:
            return image.jpeg({ quality });
    }
}

async function compressToTargetSize(buffer, targetBytes, metadata, outputFormat) {
    let quality = 90;
    let bestBuffer = buffer;
    let bestSize = buffer.length;
    
    const minQuality = 10;
    const maxIterations = 8;
    
    for (let i = 0; i < maxIterations && quality >= minQuality; i++) {
        try {
            let image = sharp(buffer);
            image = applyQualityCompression(image, quality, outputFormat);
            const outputBuffer = await image.toBuffer();
            
            if (outputBuffer.length <= targetBytes) {
                logger.info('Target size achieved', {
                    targetBytes,
                    achievedBytes: outputBuffer.length,
                    quality
                });
                return { 
                    buffer: outputBuffer, 
                    compressed: true,
                    mimeType: `image/${outputFormat}`
                };
            }
            
            if (outputBuffer.length < bestSize) {
                bestBuffer = outputBuffer;
                bestSize = outputBuffer.length;
            }
            
            const ratio = targetBytes / outputBuffer.length;
            quality = Math.max(minQuality, Math.floor(quality * Math.sqrt(ratio)));
            
        } catch (error) {
            logger.error('Compression iteration failed', { error: error.message, quality });
            break;
        }
    }
    
    // If we couldn't hit target, also try resizing
    if (bestSize > targetBytes) {
        try {
            const scaleFactor = Math.sqrt(targetBytes / bestSize);
            const newWidth = Math.floor(metadata.width * scaleFactor);
            const newHeight = Math.floor(metadata.height * scaleFactor);
            
            let image = sharp(buffer)
                .resize({ width: newWidth, height: newHeight });
            image = applyQualityCompression(image, minQuality, outputFormat);
            const resizedBuffer = await image.toBuffer();
            
            if (resizedBuffer.length < bestSize) {
                bestBuffer = resizedBuffer;
                bestSize = resizedBuffer.length;
            }
        } catch (error) {
            logger.error('Resize compression failed', { error: error.message });
        }
    }

    logger.warn('Could not achieve target size', {
        targetBytes,
        achievedBytes: bestSize
    });
    
    return { 
        buffer: bestBuffer, 
        compressed: true,
        mimeType: `image/${outputFormat}`
    };
}

module.exports = {
    parseCompressionCommand,
    compressImage,
    isImageSupported
};
