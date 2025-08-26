const express = require('express');
const {validateToken, validateRequest, getCdnUrl} = require('./utils');
const {uploadEndpoint, handleUpload} = require('./upload');
const logger = require('../config/logger');

const router = express.Router();

// Require valid API token for all routes
router.use((req, res, next) => {
    const tokenCheck = validateToken(req);
    if (tokenCheck.status !== 200) {
        return res.status(tokenCheck.status).json(tokenCheck.body);
    }
    next();
});

// Health check route
router.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' });
});

// Format response based on API version compatibility
const formatResponse = (results, version) => {
    switch (version) {
        case 1:
            return results.map(r => r.url);
        case 2:
            return results.reduce((acc, r, i) => {
                const fileName = r.url.split('/').pop();
                acc[`${i}${fileName}`] = r.url;
                return acc;
            }, {});
        default:
            return {
                files: results.map((r, i) => ({
                    deployedUrl: r.url,
                    file: `${i}_${r.url.split('/').pop()}`,
                    sha: r.sha,
                    size: r.size
                })),
                cdnBase: getCdnUrl()
            };
    }
};

const validateUrls = (urls) => {
    if (!Array.isArray(urls) || !urls.length) {
        return {
            status: 400,
            body: {
                error: {
                    message: 'Empty/invalid file array',
                    code: 'INVALID_INPUT'
                },
                success: false
            }
        };
    }

    if (urls.some(url => typeof url !== 'string' || !url.trim())) {
        return {
            status: 400,
            body: {
                error: {
                    message: 'Invalid URL format in the array',
                    code: 'INVALID_INPUT'
                },
                success: false
            }
        };
    }

    return { status: 200 };
};

// API Routes
const bulkUploadHandler = (version) => async (req, res) => {
    try {
        const urls = req.body;

        const validationResult = validateUrls(urls);
        if (validationResult.status !== 200) {
            return res.status(validationResult.status).json(validationResult.body);
        }

        const downloadAuth = req.headers?.['x-download-authorization'];
        // Process all URLs concurrently
        logger.debug(`Processing ${urls.length} URLs`);
        const results = await Promise.all(
            urls.map(url => uploadEndpoint(url, downloadAuth))
        );

        res.json(formatResponse(results, version));
    } catch (error) {
        logger.error('Bulk upload failed:', error);
        res.status(500).json({
            error: {
                message: 'Internal server error',
                code: 'INTERNAL_ERROR'
            },
            success: false
        });
    }
};

router.post('/v1/new', bulkUploadHandler(1));  // Legacy support
router.post('/v2/new', bulkUploadHandler(2));  // Legacy support
router.post('/v3/new', bulkUploadHandler(3));  // Current version
router.post('/new', bulkUploadHandler(3));     // Alias for v3 (latest)

// Single file upload endpoint
router.post('/upload', async (req, res) => {
    try {
        const result = await handleUpload(req);
        res.status(result.status).json(result.body);
    } catch (error) {
        logger.error('S3 upload handler error:', error);
        res.status(500).json({
            error: {
                message: 'Storage upload failed',
                code: 'STORAGE_FAILED'
            }
        });
    }
});

module.exports = router;
