const logger = require('./src/config/logger');

logger.info('Starting CDN application 🚀');

const express = require('express');
const cors = require('cors');
const apiRoutes = require('./src/api/index.js');

// API server
const expressApp = express();
expressApp.use(cors());
expressApp.use(express.json());
expressApp.use(express.urlencoded({ extended: true }));

// Mount API for all versions
expressApp.use('/api', apiRoutes);

// redirect route to "https://github.com/hackclub/cdn"
expressApp.get('/', (req, res) => {
    res.redirect('https://github.com/hackclub/cdn');
});

// Error handling middleware
expressApp.use((err, req, res, next) => {
    logger.error('API Error:', {
        error: err.message,
        stack: err.stack,
        path: req.path,
        method: req.method
    });
    res.status(500).json({ error: 'Internal server error' });
});

// Fallback route for unhandled paths
expressApp.use((req, res, next) => {
    logger.warn(`Unhandled route: ${req.method} ${req.path}`);
    res.status(404).json({ error: 'Not found' });
});

// Startup LOGs
(async () => {
    try {
        const port = parseInt(process.env.PORT || '4553', 10);
        expressApp.listen(port, () => {
            logger.info('CDN started successfully 🔥', {
                apiPort: port,
                startTime: new Date().toISOString()
            });
        });
    } catch (error) {
        logger.error('Failed to start application:', {
            error: error.message,
            stack: error.stack
        });
        process.exit(1);
    }
})();
