const { S3Client, PutObjectCommand, CreateMultipartUploadCommand, UploadPartCommand, CompleteMultipartUploadCommand, AbortMultipartUploadCommand } = require('@aws-sdk/client-s3');
const { FetchHttpHandler } = require('@smithy/fetch-http-handler');
const crypto = require('crypto');
const logger = require('./config/logger');
const {generateFileUrl} = require('./utils');

const MAX_FILE_SIZE = 2 * 1024 * 1024 * 1024;  // 2GB in bytes
const CONCURRENT_UPLOADS = 3;                    // Max concurrent uploads (messages)

// processed messages
const processedMessages = new Map();

let uploadLimit;

async function initialize() {
    const pLimit = (await import('p-limit')).default;
    uploadLimit = pLimit(CONCURRENT_UPLOADS);
}

// Check if the message is older than 24 hours for when the bot was offline
function isMessageTooOld(eventTs) {
    const eventTime = parseFloat(eventTs) * 1000;
    const currentTime = Date.now();
    const timeDifference = currentTime - eventTime;
    const maxAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    return timeDifference > maxAge;
}

// check if the message has already been processed
function isMessageProcessed(messageTs) {
    return processedMessages.has(messageTs);
}

function markMessageAsProcessing(messageTs) {
    processedMessages.set(messageTs, true);
}

// Processing reaction
async function addProcessingReaction(client, event, fileMessage) {
    try {
        await client.reactions.add({
            name: 'beachball',
            timestamp: fileMessage.ts,
            channel: event.channel_id
        });
    } catch (error) {
        logger.error('Failed to add processing reaction:', error.message);
    }
}

// sanitize file names and ensure it's not empty (I don't even know if that's possible but let's be safe)
function sanitizeFileName(fileName) {
    let sanitizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
    if (!sanitizedFileName) {
        sanitizedFileName = 'upload_' + Date.now();
    }
    return sanitizedFileName;
}

// Generate a unique file name
function generateUniqueFileName(fileName) {
    const sanitizedFileName = sanitizeFileName(fileName);
    const uniqueFileName = `${Date.now()}-${crypto.randomBytes(16).toString('hex')}-${sanitizedFileName}`;
    return uniqueFileName;
}

function calculatePartSize(fileSize) {
    const MIN_PSIZE = 5242880; // r2 has a 5mb min part size (except last part)
    const MAX_PSIZE = 100 * 1024 * 1024; // 100mb maximum per part
    const MAX_PARTS = 1000; // aws limit
    
    let partSize = MIN_PSIZE;
    
    if (fileSize / MIN_PSIZE > MAX_PARTS) {
        partSize = Math.ceil(fileSize / MAX_PARTS);
    }
    
    // hardcode a bit
    if (fileSize > 100 * 1024 * 1024) partSize = Math.max(partSize, 10 * 1024 * 1024); // >100mb use 10mb parts
    if (fileSize > 500 * 1024 * 1024) partSize = Math.max(partSize, 25 * 1024 * 1024); // >500mb use 25mb parts  
    if (fileSize > 1024 * 1024 * 1024) partSize = Math.max(partSize, 50 * 1024 * 1024); // >1gb use 50mb parts
    
    return Math.min(Math.max(partSize, MIN_PSIZE), MAX_PSIZE);
}

// download file using 206 partial content in chunks for slack only
async function downloadFileInChunks(url, fileSize, authHeader) {
    logger.debug('Attempting chunked download', { url, fileSize, chunks: 4 });
    
    // First, check if server supports range requests
    try {
        const headResponse = await fetch(url, {
            method: 'HEAD',
            headers: { Authorization: authHeader }
        });
        
        if (!headResponse.ok) {
            throw new Error(`HEAD request failed: ${headResponse.status}`);
        }
        
        const acceptsRanges = headResponse.headers.get('accept-ranges');
        if (acceptsRanges !== 'bytes') {
            logger.warn('Server may not support range requests', { acceptsRanges });
        }
        
        // Verify the file size matches
        const contentLength = parseInt(headResponse.headers.get('content-length') || '0');
        if (contentLength !== fileSize && contentLength > 0) {
            logger.warn('File size mismatch detected', { 
                expectedSize: fileSize, 
                actualSize: contentLength 
            });
            // Use the actual size from the server
            fileSize = contentLength;
        }
        
    } catch (headError) {
        logger.warn('HEAD request failed, proceeding with chunked download anyway', { 
            error: headError.message 
        });
    }
    
    const chunkSize = Math.ceil(fileSize / 4);
    const chunks = [];
    
    try {
        // Download all chunks in parallel
        const chunkPromises = [];
        
        for (let i = 0; i < 4; i++) {
            const start = i * chunkSize;
            const end = Math.min(start + chunkSize - 1, fileSize - 1);
            
            chunkPromises.push(downloadChunk(url, start, end, authHeader, i));
        }
        
        const chunkResults = await Promise.all(chunkPromises);
        
        // Verify all chunks downloaded successfully
        for (let i = 0; i < chunkResults.length; i++) {
            if (!chunkResults[i]) {
                throw new Error(`Chunk ${i} failed to download`);
            }
            chunks[i] = chunkResults[i];
        }
        
        // Combine all chunks into a single buffer
        const totalBuffer = Buffer.concat(chunks);
        
        logger.debug('Chunked download successful', { 
            totalSize: totalBuffer.length,
            expectedSize: fileSize 
        });
        
        return totalBuffer;
        
    } catch (error) {
        logger.error('Chunked download failed', { error: error.message });
        throw error;
    }
}

// Download a single chunk using Range header
async function downloadChunk(url, start, end, authHeader, chunkIndex, retryCount = 0) {
    const maxRetries = 3;
    
    try {
        logger.debug(`Downloading chunk ${chunkIndex} (attempt ${retryCount + 1})`, { 
            start, 
            end, 
            size: end - start + 1 
        });
        
        const response = await fetch(url, {
            headers: {
                'Authorization': authHeader,
                'Range': `bytes=${start}-${end}`
            }
        });
        
        if (!response.ok) {
            throw new Error(`Chunk ${chunkIndex} download failed: ${response.status} ${response.statusText}`);
        }
        
        // Check if server supports partial content
        if (response.status !== 206) {
            // If it's a 200 response, the server might be returning the whole file
            if (response.status === 200) {
                logger.warn(`Chunk ${chunkIndex}: Server returned full file instead of partial content`);
                const fullBuffer = await response.buffer();
                
                // Extract just the chunk we need from the full file
                const chunkBuffer = fullBuffer.slice(start, end + 1);
                
                logger.debug(`Chunk ${chunkIndex} extracted from full download`, { 
                    actualSize: chunkBuffer.length,
                    expectedSize: end - start + 1 
                });
                
                return chunkBuffer;
            } else {
                throw new Error(`Server doesn't support partial content, got status ${response.status}`);
            }
        }
        
        const buffer = await response.buffer();
        
        // Verify chunk size
        const expectedSize = end - start + 1;
        if (buffer.length !== expectedSize) {
            throw new Error(`Chunk ${chunkIndex} size mismatch: expected ${expectedSize}, got ${buffer.length}`);
        }
        
        logger.debug(`Chunk ${chunkIndex} downloaded successfully`, { 
            actualSize: buffer.length,
            expectedSize: expectedSize 
        });
        
        return buffer;
        
    } catch (error) {
        logger.error(`Chunk ${chunkIndex} download failed (attempt ${retryCount + 1})`, { 
            error: error.message 
        });
        
        // Retry logic
        if (retryCount < maxRetries) {
            const delay = Math.pow(2, retryCount) * 1000; // Exponential backoff
            logger.debug(`Retrying chunk ${chunkIndex} in ${delay}ms`);
            
            await new Promise(resolve => setTimeout(resolve, delay));
            return downloadChunk(url, start, end, authHeader, chunkIndex, retryCount + 1);
        }
        
        throw error;
    }
}

// upload files to the /s/ directory
async function processFiles(fileMessage, client) {
    const uploadedFiles = [];
    const failedFiles = [];

    logger.debug('Starting file processing', {
        userId: fileMessage.user,
        fileCount: fileMessage.files?.length || 0
    });

    const files = fileMessage.files || [];
    for (const file of files) {
        logger.debug('Processing file', {
            name: file.name,
            size: file.size,
            type: file.mimetype,
            id: file.id
        });

        if (file.size > MAX_FILE_SIZE) {
            logger.warn('File exceeds size limit', {
                name: file.name,
                size: file.size,
                limit: MAX_FILE_SIZE
            });
            failedFiles.push(file.name);
            continue;
        }

        try {
            logger.debug('Fetching file from Slack', {
                name: file.name,
                url: file.url_private
            });

            let uploadData;
            const authHeader = `Bearer ${process.env.SLACK_BOT_TOKEN}`;
            
            try {
                const response = await fetch(file.url_private, {
                    headers: { Authorization: authHeader }
                });

                if (!response.ok) {
                    throw new Error(`Slack download failed: ${response.status} ${response.statusText}`);
                }

                uploadData = await response.buffer();
                logger.debug('File downloaded', { 
                    fileName: file.name, 
                    size: uploadData.length 
                });
                
            } catch (downloadError) {
                logger.warn('Regular download failed, trying chunked download', {
                    fileName: file.name,
                    error: downloadError.message
                });
                
                try {
                    uploadData = await downloadFileInChunks(file.url_private, file.size, authHeader);
                    logger.info('Chunked download successful as fallback', {
                        fileName: file.name,
                        size: uploadData.length
                    });
                } catch (chunkedError) {
                    logger.error('Both regular and chunked downloads failed', {
                        fileName: file.name,
                        regularError: downloadError.message,
                        chunkedError: chunkedError.message
                    });
                    throw new Error(`All download methods failed. Regular: ${downloadError.message}, Chunked: ${chunkedError.message}`);
                }
            }

            const contentType = file.mimetype || 'application/octet-stream';
            const uniqueFileName = generateUniqueFileName(file.name);
            const userDir = `s/${fileMessage.user}`;

            const uploadResult = await uploadLimit(() => 
                uploadToStorage(userDir, uniqueFileName, uploadData, contentType, file.size)
            );
            
            if (uploadResult.success === false) {
                throw new Error(uploadResult.error);
            }

            const url = generateFileUrl(userDir, uniqueFileName);
            uploadedFiles.push({
                name: uniqueFileName, 
                url,
                contentType
            });
        } catch (error) {
            logger.error('File processing failed', {
                fileName: file.name,
                error: error.message,
                stack: error.stack,
                slackFileId: file.id,
                userId: fileMessage.user
            });
            failedFiles.push(file.name);
        }
    }

    logger.debug('File processing complete', {
        successful: uploadedFiles.length,
        failed: failedFiles.length
    });

    return {uploadedFiles, failedFiles};
}

// update reactions based on success
async function updateReactions(client, event, fileMessage, success) {
    try {
        await client.reactions.remove({
            name: 'beachball',
            timestamp: fileMessage.ts,
            channel: event.channel_id
        });
        await client.reactions.add({
            name: success ? 'white_check_mark' : 'x',
            timestamp: fileMessage.ts,
            channel: event.channel_id
        });
    } catch (error) {
        logger.error('Failed to update reactions:', error.message);
    }
}

// find a file message
async function findFileMessage(event, client) {
    try {
        const fileInfo = await client.files.info({
            file: event.file_id,
            include_shares: true
        });

        if (!fileInfo.ok || !fileInfo.file) {
            throw new Error('Could not get file info');
        }

        const channelShare = fileInfo.file.shares?.public?.[event.channel_id] ||
            fileInfo.file.shares?.private?.[event.channel_id];

        if (!channelShare || !channelShare.length) {
            throw new Error('No share info found for this channel');
        }

        // Get the exact message using the ts from share info
        const messageTs = channelShare[0].ts;

        const messageInfo = await client.conversations.history({
            channel: event.channel_id,
            latest: messageTs,
            limit: 1,
            inclusive: true
        });

        if (!messageInfo.ok || !messageInfo.messages.length) {
            throw new Error('Could not find original message');
        }

        return messageInfo.messages[0];
    } catch (error) {
        logger.error('Error finding file message:', error);
        return null;
    }
}

async function sendResultsMessage(client, channelId, fileMessage, uploadedFiles, failedFiles) {
    let message = `Hey <@${fileMessage.user}>, `;
    if (uploadedFiles.length > 0) {
        message += `here ${uploadedFiles.length === 1 ? 'is your link' : 'are your links'}:\n`;
        message += uploadedFiles.map(f => `• ${f.name}: ${f.url}`).join('\n');
    }
    if (failedFiles.length > 0) {
        message += `\n\nFailed to process: ${failedFiles.join(', ')}`;
    }

    await client.chat.postMessage({
        channel: channelId,
        thread_ts: fileMessage.ts,
        text: message
    });
}

async function handleError(client, channelId, fileMessage, reactionAdded) {
    if (fileMessage && reactionAdded) {
        try {
            await client.reactions.remove({
                name: 'beachball',
                timestamp: fileMessage.ts,
                channel: channelId
            });
        } catch (cleanupError) {
            if (cleanupError.data.error !== 'no_reaction') {
                logger.error('Cleanup error:', cleanupError);
            }
        }
        try {
            await client.reactions.add({
                name: 'x',
                timestamp: fileMessage.ts,
                channel: channelId
            });
        } catch (cleanupError) {
            logger.error('Cleanup error:', cleanupError);
        }
    }
}

async function handleFileUpload(event, client) {
    let fileMessage = null;
    let reactionAdded = false;

    try {
        if (isMessageTooOld(event.event_ts)) return;

        fileMessage = await findFileMessage(event, client);
        if (!fileMessage || isMessageProcessed(fileMessage.ts)) return;

        markMessageAsProcessing(fileMessage.ts);
        await addProcessingReaction(client, event, fileMessage);
        reactionAdded = true;

        const {uploadedFiles, failedFiles} = await processFiles(fileMessage, client);
        await sendResultsMessage(client, event.channel_id, fileMessage, uploadedFiles, failedFiles);

        await updateReactions(client, event, fileMessage, failedFiles.length === 0);

    } catch (error) {
        logger.error('Upload failed:', error.message);
        await handleError(client, event.channel_id, fileMessage, reactionAdded);
        throw error;
    }
}

const s3Client = new S3Client({
    region: process.env.AWS_REGION,
    endpoint: process.env.AWS_ENDPOINT,
    requestHandler: new FetchHttpHandler(),
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    },
    forcePathStyle: true,
    requestTimeout: 300000,
    maxAttempts: 3
});

async function uploadToStorage(userDir, uniqueFileName, bodyData, contentType = 'application/octet-stream', fileSize) {
    try {
        const key = `${userDir}/${uniqueFileName}`;
        
        if (fileSize >= 10485760) { // 10mb threshold
            return await uploadMultipart(key, bodyData, contentType);
        } else {
            const params = {
                Bucket: process.env.AWS_BUCKET_NAME,
                Key: key,
                Body: bodyData,
                ContentType: contentType,
                CacheControl: 'public, immutable, max-age=31536000'
            };

            logger.info(`Single part upload: ${key}`);
            await s3Client.send(new PutObjectCommand(params));
            return { success: true };
        }
    } catch (error) {
        logger.error(`Upload failed: ${error.message}`, { 
            path: `${userDir}/${uniqueFileName}`,
            error: error.message
        });
        return { success: false, error: error.message };
    }
}

async function uploadMultipart(key, bodyData, contentType) {
    let uploadId;
    
    try {
        const createParams = {
            Bucket: process.env.AWS_BUCKET_NAME,
            Key: key,
            ContentType: contentType,
            CacheControl: 'public, immutable, max-age=31536000'
        };

        const createResult = await s3Client.send(new CreateMultipartUploadCommand(createParams));
        uploadId = createResult.UploadId;
        
        const partSize = calculatePartSize(bodyData.length);
        const totalParts = Math.ceil(bodyData.length / partSize);
        
        logger.info(`multipart upload: ${key}`, { 
            uploadId, 
            fileSize: bodyData.length,
            partSize,
            totalParts
        });

        const uploadPromises = [];

        for (let partNumber = 1; partNumber <= totalParts; partNumber++) {
            const start = (partNumber - 1) * partSize;
            const end = Math.min(start + partSize, bodyData.length); // last part can be below 5mb and below but not above normal part size
            const partData = bodyData.slice(start, end);

            const uploadPartParams = {
                Bucket: process.env.AWS_BUCKET_NAME,
                Key: key,
                PartNumber: partNumber,
                UploadId: uploadId,
                Body: partData
            };

            const uploadPromise = s3Client.send(new UploadPartCommand(uploadPartParams))
                .then(result => ({
                    PartNumber: partNumber,
                    ETag: result.ETag
                }));

            uploadPromises.push(uploadPromise);
        }

        const parts = await Promise.all(uploadPromises);
        parts.sort((a, b) => a.PartNumber - b.PartNumber);

        const completeParams = {
            Bucket: process.env.AWS_BUCKET_NAME,
            Key: key,
            UploadId: uploadId,
            MultipartUpload: { Parts: parts }
        };

        await s3Client.send(new CompleteMultipartUploadCommand(completeParams));
        logger.info(`multipart upload completed: ${key}`);
        
        return { success: true };

    } catch (error) {
        if (uploadId) {
            try {
                await s3Client.send(new AbortMultipartUploadCommand({
                    Bucket: process.env.AWS_BUCKET_NAME,
                    Key: key,
                    UploadId: uploadId
                }));
                logger.info(`aborted multipart upload: ${key}`);
            } catch (abortError) {
                logger.error(`failed to abort multipart upload: ${abortError.message}`);
            }
        }
        throw error;
    }
}

module.exports = { 
    handleFileUpload, 
    initialize,
    uploadToStorage,
    downloadFileInChunks,
    downloadChunk
};
