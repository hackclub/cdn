const fs = require('fs');
const path = require('path');
const {uploadToStorage} = require('./storage');
const {generateFileUrl} = require('./utils');
const logger = require('./config/logger');

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
        const uploadResult = await uploadToStorage('s/v3', uniqueFileName, buffer, contentType);
        if (!uploadResult.success) {
            throw new Error(uploadResult.error || 'Storage upload failed');
        }

        return {
            success: true,
            name: fileName,
            url: generateFileUrl('s/v3', uniqueFileName),
            contentType
        };
    } catch (error) {
        logger.error('Upload failed:', error);
        return {
            success: false,
            error: error.message
        };
    } finally {
        // Clean up the temporary file
        if (fs.existsSync(file.path)) {
            fs.unlinkSync(file.path);
        }
    }
};

module.exports = {handleUpload};
