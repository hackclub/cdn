const fs = require('fs');
const path = require('path');
const {uploadToBackblaze} = require('../backblaze');
const {generateUrl} = require('./utils');
const logger = require('../config/logger');

// Handle individual file upload
const handleUpload = async (file) => {
    try {
        const buffer = fs.readFileSync(file.path);
        const fileName = path.basename(file.originalname);
        const uniqueFileName = `${Date.now()}-${fileName}`;

        // Upload to B2 storage
        logger.debug(`Uploading: ${uniqueFileName}`);
        const uploaded = await uploadToBackblaze('s/v3', uniqueFileName, buffer);
        if (!uploaded) throw new Error('Storage upload failed');

        return {
            name: fileName,
            url: generateUrl('s/v3', uniqueFileName)
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
