const fs = require('fs');
const path = require('path');
const {uploadToStorage} = require('../storage');
const {generateUrl} = require('./utils');
const logger = require('../config/logger');

// Handle individual file upload
const handleUpload = async (file) => {
    try {
        const buffer = fs.readFileSync(file.path);
        const fileName = path.basename(file.originalname);
        // Add content type detection for S3
        const contentType = file.mimetype || 'application/octet-stream';
        const uniqueFileName = `${Date.now()}-${fileName}`;

        // Upload to S3 storage with content type
        logger.debug(`Uploading: ${uniqueFileName}`);
        const uploaded = await uploadToStorage('s/v3', uniqueFileName, buffer, contentType);
        if (!uploaded) throw new Error('Storage upload failed');

        return {
            name: fileName,
            url: generateUrl('s/v3', uniqueFileName),
            contentType
        };
    } catch (error) {
        logger.error('Upload failed:', error);
        throw error;
    } finally {
        // Clean up the temporary file
        fs.unlinkSync(file.path);
    }
};

module.exports = {handleUpload};
