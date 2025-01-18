const dotenv = require('dotenv');
dotenv.config();

const logger = require('./src/config/logger');
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

// Log ALL incoming requests for debugging
expressApp.use((req, res, next) => {
    logger.info(`Incoming request: ${req.method} ${req.path}`);
    next();
});

// Log statement before mounting the API routes
logger.info('Mounting API routes');

// Mount API for all versions
expressApp.use('/api', apiRoutes);

// Error handling middleware
expressApp.use((err, req, res, next) => {
    logger.error('API Error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

// Fallback route for unhandled paths
expressApp.use((req, res, next) => {
    logger.warn(`Unhandled route: ${req.method} ${req.path}`);
    res.status(404).json({ error: 'Not found' });
});

// Event listener for file_shared events
app.event('file_shared', async ({event, client}) => {
    logger.debug(`Received file_shared event: ${JSON.stringify(event)}`);

    if (parseFloat(event.event_ts) < BOT_START_TIME) {
        logger.info(`Ignoring file event from before bot start: ${new Date(parseFloat(event.event_ts) * 1000).toISOString()}`);
        return;
    }

    const targetChannelId = process.env.SLACK_CHANNEL_ID;
    const channelId = event.channel_id;

    if (channelId !== targetChannelId) {
        logger.info(`Ignoring file shared in channel: ${channelId}`);
        return;
    }

    try {
        await fileUpload.handleFileUpload(event, client);
    } catch (error) {
        logger.error(`Error processing file upload: ${error.message}`);
    }
});

// Slack bot and API server
(async () => {
    try {
        await fileUpload.initialize();
        await app.start();
        const port = parseInt(process.env.API_PORT || '4553', 10);
        expressApp.listen(port, () => {
            logger.info(`⚡️ Slack app is running in Socket Mode!`);
            logger.info(`🚀 API server is running on port ${port}`);
        });
    } catch (error) {
        logger.error('Failed to start:', error);
        process.exit(1);
    }
})();
