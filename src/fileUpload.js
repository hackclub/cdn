const fetch = require('node-fetch');
const crypto = require('crypto');
const logger = require('./config/logger');
const storage = require('./storage');
const {generateFileUrl} = require('./utils');
const path = require('path');
const { 
    messages, 
    formatSuccessMessage, 
    formatErrorMessage,
    getFileTypeMessage 
} = require('./config/messages');

const MAX_FILE_SIZE = 50 * 1024 * 1024;  // 50MB in bytes
const CONCURRENT_UPLOADS = 3;                    // Max concurrent uploads (messages)

const processedMessages = new Map();
let uploadLimit;

async function initialize() {
    const pLimit = (await import('p-limit')).default;
    uploadLimit = pLimit(CONCURRENT_UPLOADS);
}

// Basic stuff
function isMessageTooOld(eventTs) {
    const eventTime = parseFloat(eventTs) * 1000;
    return (Date.now() - eventTime) > 24 * 60 * 60 * 1000;
}

function isMessageProcessed(messageTs) {
    return processedMessages.has(messageTs);
}

function markMessageAsProcessing(messageTs) {
    processedMessages.set(messageTs, true);
}

// File processing
function sanitizeFileName(fileName) {
    let sanitized = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
    return sanitized || `upload_${Date.now()}`;
}

function generateUniqueFileName(fileName) {
    return `${Date.now()}-${crypto.randomBytes(16).toString('hex')}-${sanitizeFileName(fileName)}`;
}

// upload functionality
async function processFiles(fileMessage, client) {
    const uploadedFiles = [];
    const failedFiles = [];
    const sizeFailedFiles = [];
    const fileTypeResponses = new Set();

    logger.info(`Processing ${fileMessage.files?.length || 0} files`);

    for (const file of fileMessage.files || []) {
        try {
            if (file.size > MAX_FILE_SIZE) {
                sizeFailedFiles.push(file.name);
                continue;
            }

            // Get file extension message if applicable
            const ext = path.extname(file.name).slice(1);
            const typeMessage = getFileTypeMessage(ext);
            if (typeMessage) fileTypeResponses.add(typeMessage);

            const response = await fetch(file.url_private, {
                headers: {Authorization: `Bearer ${process.env.SLACK_BOT_TOKEN}`}
            });

            if (!response.ok) throw new Error('Download failed');

            const buffer = await response.buffer();
            const uniqueFileName = generateUniqueFileName(file.name);
            const userDir = `s/${fileMessage.user}`;

            const success = await uploadLimit(() => 
                storage.uploadToStorage(userDir, uniqueFileName, buffer, file.mimetype)
            );

            if (!success) throw new Error('Upload failed');

            uploadedFiles.push({
                name: uniqueFileName,
                originalName: file.name,
                url: generateFileUrl(userDir, uniqueFileName),
                contentType: file.mimetype
            });

        } catch (error) {
            logger.error(`Failed: ${file.name} - ${error.message}`);
            failedFiles.push(file.name);
        }
    }

    return {
        uploadedFiles, 
        failedFiles,
        sizeFailedFiles,
        isSizeError: sizeFailedFiles.length > 0
    };
}

// Slack interaction
async function addProcessingReaction(client, event, fileMessage) {
    try {
        await client.reactions.add({
            name: 'beachball',
            timestamp: fileMessage.ts,
            channel: event.channel_id
        });
    } catch (error) {
        logger.error('Failed to add reaction:', error.message);
    }
}

async function updateReactions(client, event, fileMessage, totalFiles, failedCount) {
    try {
        await client.reactions.remove({
            name: 'beachball',
            timestamp: fileMessage.ts,
            channel: event.channel_id
        });

        // Choose reaction based on how many files failed or well succeded
        let reactionName;
        if (failedCount === totalFiles) {
            reactionName = 'x';  // All files failed
        } else if (failedCount > 0) {
            reactionName = 'warning';  // Some files failed
        } else {
            reactionName = 'white_check_mark';  // All files succeeded
        }

        await client.reactions.add({
            name: reactionName,
            timestamp: fileMessage.ts,
            channel: event.channel_id
        });
    } catch (error) {
        logger.error('Failed to update reactions:', error.message);
    }
}

async function findFileMessage(event, client) {
    try {
        const result = await client.conversations.history({
            channel: event.channel_id,
            latest: event.event_ts,
            inclusive: true,
            limit: 1
        });

        if (!result.ok || !result.messages.length) {
            throw new Error('Could not find original message');
        }

        const message = result.messages[0];
        // Ensure message has files
        if (!message.files || message.files.length === 0) {
            throw new Error('No files found in message');
        }

        return message;
    } catch (error) {
        logger.error('Error finding file message:', error);
        return null;
    }
}

async function sendResultsMessage(client, channelId, fileMessage, uploadedFiles, failedFiles, sizeFailedFiles) {
    try {
        let message;
        if (uploadedFiles.length === 0 && (failedFiles.length > 0 || sizeFailedFiles.length > 0)) {
            // All files failed - use appropriate error type
            message = formatErrorMessage(
                [...failedFiles, ...sizeFailedFiles],
                sizeFailedFiles.length > 0 && failedFiles.length === 0  // Only use size error if all failures are size-related (i hope this is how it makes most sense)
            );
        } else {
            // Mixed success/failure or all success
            message = formatSuccessMessage(
                fileMessage.user,
                uploadedFiles,
                failedFiles,
                sizeFailedFiles
            );
        }

        const lines = message.split('\n');
        const attachments = [];
        let textBuffer = '';

        for (const line of lines) {
            if (line.match(/^<.*\|image>$/)) {
                const imageUrl = line.replace(/^<|>$/g, '').replace('|image', '');
                attachments.push({
                    image_url: imageUrl,
                    fallback: 'Error image'
                });
            } else {
                textBuffer += line + '\n';
            }
        }

        await client.chat.postMessage({
            channel: channelId,
            thread_ts: fileMessage.ts,
            text: textBuffer.trim(),
            attachments: attachments.length > 0 ? attachments : undefined
        });
    } catch (error) {
        logger.error('Failed to send results message:', error);
        throw error;
    }
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

        // Get the message using conversations.history
        const messages = await client.conversations.history({
            channel: event.channel_id,
            latest: event.event_ts,
            inclusive: true,
            limit: 1
        });

        if (!messages.ok || !messages.messages.length) {
            throw new Error('Could not find message');
        }

        fileMessage = messages.messages[0];
        if (!fileMessage || isMessageProcessed(fileMessage.ts)) return;

        markMessageAsProcessing(fileMessage.ts);
        await addProcessingReaction(client, event, fileMessage);
        reactionAdded = true;

        const {uploadedFiles, failedFiles, sizeFailedFiles} = await processFiles(fileMessage, client);
        
        const totalFiles = uploadedFiles.length + failedFiles.length + sizeFailedFiles.length;
        const failedCount = failedFiles.length + sizeFailedFiles.length;

        await sendResultsMessage(
            client,
            event.channel_id,
            fileMessage,
            uploadedFiles,
            failedFiles,
            sizeFailedFiles
        );

        await updateReactions(
            client, 
            event, 
            fileMessage, 
            totalFiles, 
            failedCount
        );

    } catch (error) {
        logger.error(`Upload failed: ${error.message}`);
        await handleError(client, event.channel_id, fileMessage, reactionAdded);
        throw error;
    }
}

module.exports = { handleFileUpload, initialize };
