const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const path = require('path');
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

// Generate a unique, non-guessable file name
function generateUniqueFileName(fileName) {
    const sanitizedFileName = sanitizeFileName(fileName);
    const uniqueFileName = `${Date.now()}-${crypto.randomBytes(16).toString('hex')}-${sanitizedFileName}`;
    return uniqueFileName;
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

            const response = await fetch(file.url_private, {
                headers: {Authorization: `Bearer ${process.env.SLACK_BOT_TOKEN}`}
            });

            if (!response.ok) {
                throw new Error(`Slack download failed: ${response.status} ${response.statusText}`);
            }

            const buffer = await response.buffer();
            const contentType = file.mimetype || 'application/octet-stream';
            const uniqueFileName = generateUniqueFileName(file.name);
            const userDir = `s/${fileMessage.user}`;

            const uploadResult = await uploadLimit(() => 
                uploadToStorage(userDir, uniqueFileName, buffer, contentType)
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
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    }
});

async function uploadToStorage(userDir, uniqueFileName, buffer, contentType = 'application/octet-stream') {
    try {
        const params = {
            Bucket: process.env.AWS_BUCKET_NAME,
            Key: `${userDir}/${uniqueFileName}`,
            Body: buffer,
            ContentType: contentType,
            CacheControl: 'public, immutable, max-age=31536000'
        };

        logger.info(`Uploading: ${uniqueFileName}`);
        await s3Client.send(new PutObjectCommand(params));
        return true;
    } catch (error) {
        logger.error(`Upload failed: ${error.message}`, { 
            path: `${userDir}/${uniqueFileName}`,
            error: error.message
        });
        return false;
    }
}

module.exports = { 
    handleFileUpload, 
    initialize,
    uploadToStorage
};
