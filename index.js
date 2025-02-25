const dotenv = require('dotenv');
dotenv.config();

const logger = require('./src/config/logger');

logger.info('Starting CDN application 🚀');

const {App} = require('@slack/bolt');
const fileUpload = require('./src/fileUpload');
const express = require('express');
const cors = require('cors');
const apiRoutes = require('./src/api/index.js');

const BOT_START_TIME = Date.now() / 1000;

const app = new App({
    token: process.env.SLACK_BOT_TOKEN,
    signingSecret: process.env.SLACK_SIGNING_SECRET,
    socketMode: true,
    appToken: process.env.SLACK_APP_TOKEN
});

// API server
const expressApp = express();
expressApp.use(cors());
expressApp.use(express.json());
expressApp.use(express.urlencoded({ extended: true }));

// Mount API for all versions
expressApp.use('/api', apiRoutes);

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

// Event listener for file_shared events
app.event('file_shared', async ({event, client}) => {
    if (parseFloat(event.event_ts) < BOT_START_TIME) return;
    if (event.channel_id !== process.env.SLACK_CHANNEL_ID) return;

    try {
        await fileUpload.handleFileUpload(event, client);
    } catch (error) {
        logger.error(`Upload failed: ${error.message}`);
    }
});

// Startup LOGs
(async () => {
    try {
        await fileUpload.initialize();
        await app.start();
        const port = parseInt(process.env.PORT || '4553', 10);
        expressApp.listen(port, () => {
            logger.info('CDN started successfully 🔥', {
                slackMode: 'Socket Mode',
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
