const winston = require('winston');

const consoleFormat = winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp(),
    winston.format.printf(({level, message, timestamp}) => {
        return `${timestamp} ${level}: ${message}`;
    })
);

const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: consoleFormat,
    transports: [
        new winston.transports.Console()
    ]
});

logger.on('error', error => {
    console.error('Logger error:', error);
});

module.exports = logger;