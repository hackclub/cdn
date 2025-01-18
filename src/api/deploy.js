const logger = require('../config/logger');
const {generateApiUrl, getCdnUrl} = require('./utils');

const deployEndpoint = async (files) => {
    try {
        const deployedFiles = files.map(file => ({
            deployedUrl: generateApiUrl('v3', file.file),
            cdnUrl: getCdnUrl(),
            ...file
        }));

        return {
            status: 200,
            files: deployedFiles,
            cdnBase: getCdnUrl()
        };
    } catch (error) {
        logger.error('Deploy error:', error);
        return {
            status: 500,
            files: []
        };
    }
};

module.exports = {deployEndpoint};