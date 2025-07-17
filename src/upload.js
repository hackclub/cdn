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
        // content type detection for S3
        const contentType = file.mimetype || 'application/octet-stream';
        const uniqueFileName = `${Date.now()}-${fileName}`;

        // Upload to S3
        logger.debug(`Uploading: ${uniqueFileName}`);
        const uploaded = await uploadToStorage('s/v3', uniqueFileName, buffer, contentType);
        
        if (!uploaded) {
            logger.info('Upload failed!')
            throw new Error('Storage upload failed')
        };

        logger.info('File uploaded successfully:', uniqueFileName);
        const url = generateUrl('s/v3', uniqueFileName);
        logger.info('File URL:', url);

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
