const express = require('express');
const multer = require('multer');
const router = express.Router();
const logger = require('./config/logger');

// Auth middleware
const authMiddleware = (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (token !== process.env.API_TOKEN) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
};

// Configure multer
const upload = multer({
    dest: 'uploads/',
    limits: { fileSize: 2 * 1024 * 1024 * 1024 } // 2GB
});

// Add auth to all routes
router.use(authMiddleware);

router.post('/upload', upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        const result = await handleUpload(req.file);
        if (!result.success) {
            return res.status(500).json({ error: result.error });
        }

        res.json(result);
    } catch (error) {
        logger.error('Upload error:', error);
        res.status(500).json({ error: 'Upload failed' });
    }
});

module.exports = router;
