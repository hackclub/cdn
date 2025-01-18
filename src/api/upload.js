const fetch = require('node-fetch');
const crypto = require('crypto');
const {uploadToBackblaze} = require('../backblaze');
const {generateUrl, getCdnUrl} = require('./utils');
const logger = require('../config/logger');

// Sanitize file name for storage
function sanitizeFileName(fileName) {
    let sanitizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
    if (!sanitizedFileName) {
        sanitizedFileName = 'upload_' + Date.now();
    }
    return sanitizedFileName;
}

// Handle remote file upload to B2 storage
const uploadEndpoint = async (url, authorization = null) => {
    try {
        logger.debug(`Downloading: ${url}`);
        const response = await fetch(url, {
            headers: authorization ? {'Authorization': authorization} : {}
        });

        if (!response.ok) throw new Error(`Download failed: ${response.statusText}`);

        // Generate unique filename using SHA1 (hash) of file contents
        const buffer = await response.buffer();
        const sha = crypto.createHash('sha1').update(buffer).digest('hex');
        const originalName = url.split('/').pop();
        const sanitizedFileName = sanitizeFileName(originalName);
        const fileName = `${sha}_${sanitizedFileName}`;

        // Upload to B2 storage
        logger.debug(`Uploading: ${fileName}`);
        const uploaded = await uploadToBackblaze('s/v3', fileName, buffer);
        if (!uploaded) throw new Error('Storage upload failed');

        return {
            url: generateUrl('s/v3', fileName),
            sha,
            size: buffer.length
        };
    } catch (error) {
        logger.error('Upload failed:', error);
        throw error;
    }
};

// Express request handler for file uploads
const handleUpload = async (req) => {
    const url = req.body || await req.text();
    const result = await uploadEndpoint(url, req.headers?.authorization);
    return {status: 200, body: result};
};

module.exports = {uploadEndpoint, handleUpload};
