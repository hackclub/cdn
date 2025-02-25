const dotenv = require('dotenv');
dotenv.config();

const logger = require('./src/config/logger');
const { App, ExpressReceiver } = require('@slack/bolt');
const fileUpload = require('./src/fileUpload');
const express = require('express');
const cors = require('cors');
const apiRoutes = require('./src/api/index.js');

const BOT_START_TIME = Date.now() / 1000;

// Create the receiver
const receiver = new ExpressReceiver({
    signingSecret: process.env.SLACK_SIGNING_SECRET,
    processBeforeResponse: true
});

const app = new App({
    token: process.env.SLACK_BOT_TOKEN,
    receiver
});

// API server setup using the receiver's express app
const expressApp = receiver.app;
expressApp.use(cors());
expressApp.use(express.json());
expressApp.use(express.urlencoded({ extended: true }));

// Mount API routes
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
app.event('file_shared', async ({ event, client }) => {
    if (parseFloat(event.event_ts) < BOT_START_TIME) return;
    if (event.channel_id !== process.env.SLACK_CHANNEL_ID) return;

    try {
        await fileUpload.handleFileUpload(event, client);
    } catch (error) {
        logger.error(`Upload failed: ${error.message}`);
    }
});

// Startup
(async () => {
    try {
        await fileUpload.initialize();
        const port = parseInt(process.env.PORT || '4553', 10);
        await app.start(port);
        logger.info('CDN started successfully 🔥', {
            mode: 'HTTP Events',
            port: port,
            startTime: new Date().toISOString()
        });
    } catch (error) {
        logger.error('Failed to start application:', {
            error: error.message,
            stack: error.stack
        });
        process.exit(1);
    }
})();
