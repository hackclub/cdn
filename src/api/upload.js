const fetch = require('node-fetch');
const crypto = require('crypto');
const {uploadToStorage} = require('../storage');
const {generateUrl} = require('./utils');
const logger = require('../config/logger');

// Sanitize file name for storage
function sanitizeFileName(fileName) {
    let sanitizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
    if (!sanitizedFileName) {
        sanitizedFileName = 'upload_' + Date.now();
    }
    return sanitizedFileName;
}

// Handle remote file upload to S3 storage
const uploadEndpoint = async (url, downloadAuth = null) => {
    try {
        logger.debug('Starting download', { url });
        const headers = {};
        
        if (downloadAuth) {
            headers['Authorization'] = downloadAuth.startsWith('Bearer ') 
                ? downloadAuth 
                : `Bearer ${downloadAuth}`;
        }

        const response = await fetch(url, { headers });

        if (!response.ok) {
            const error = new Error(`Download failed: ${response.statusText}`);
            error.statusCode = response.status;
            error.code = 'DOWNLOAD_FAILED';
            if (response.status === 401 || response.status === 403) {
                error.code = 'AUTH_FAILED';
                error.message = 'Authentication failed for protected resource';
            }
            throw error;
        }

        // Generate unique filename using SHA1 (hash) of file contents
        const buffer = await response.buffer();
        const sha = crypto.createHash('sha1').update(buffer).digest('hex');
        const originalName = url.split('/').pop();
        const sanitizedFileName = sanitizeFileName(originalName);
        const fileName = `${sha}_${sanitizedFileName}`;

        // Upload to S3 storage
        logger.debug(`Uploading: ${fileName}`);
        const uploadResult = await uploadToStorage('s/v3', fileName, buffer, response.headers.get('content-type'), buffer.length);
        if (uploadResult.success === false) {
            const storageError = new Error(`Storage upload failed: ${uploadResult.error}`);
            storageError.statusCode = 500;
            storageError.code = 'STORAGE_FAILED';
            throw storageError;
        }

        return {
            url: generateUrl('s/v3', fileName),
            sha,
            size: buffer.length,
            type: response.headers.get('content-type')
        };
    } catch (error) {
        logger.error('Upload process failed', {
            url,
            error: error.message,
            code: error.code,
            statusCode: error.statusCode,
            stack: error.stack
        });

        let statusCode = error.statusCode || 500;
        let errorCode = error.code || 'INTERNAL_ERROR';
        let errorMessage = error.message || 'Internal server error';

        if (error.code === 'DOWNLOAD_FAILED') {
            statusCode = error.statusCode;
            errorCode = error.code;
            errorMessage = error.message;
        } else if (error.code === 'AUTH_FAILED') {
            statusCode = error.statusCode;
            errorCode = error.code;
            errorMessage = error.message;
        } else if (error.code === 'STORAGE_FAILED') {
            statusCode = error.statusCode;
            errorCode = error.code;
            errorMessage = error.message;
        } else {
            statusCode = 500;
            errorCode = 'INTERNAL_ERROR';
            errorMessage = 'Internal server error';
        }
        
        const errorResponse = {
            error: {
                message: errorMessage,
                code: errorCode,
                details: error.details || null,
                url: url
            },
            success: false
        };

        throw { statusCode, ...errorResponse };
    }
};

// Express request handler for file uploads
const handleUpload = async (req) => {
    try {
        const url = req.body || await req.text();
        const downloadAuth = req.headers?.['x-download-authorization']?.toString();
            
        if (url.includes('files.slack.com') && !downloadAuth) {
            return {
                status: 400,
                body: {
                    error: {
                        message: 'X-Download-Authorization required for Slack files',
                        code: 'AUTH_REQUIRED',
                        details: 'Slack files require authentication'
                    },
                    success: false
                }
            };
        }
        
        const result = await uploadEndpoint(url, downloadAuth);
        return { status: 200, body: result };
    } catch (error) {
        return {
            status: error.statusCode || 500,
            body: {
                error: error.error || {
                    message: 'Internal server error',
                    code: 'INTERNAL_ERROR'
                },
                success: false
            }
        };
    }
};

module.exports = {uploadEndpoint, handleUpload};
