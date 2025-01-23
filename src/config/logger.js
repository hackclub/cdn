const winston = require('winston');

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.colorize(),
        winston.format.printf(({ level, message, timestamp, ...meta }) => {
            let output = `${timestamp} ${level}: ${message}`;
            if (Object.keys(meta).length > 0) {
                output += ` ${JSON.stringify(meta)}`;
            }
            return output;
        })
    ),
    transports: [new winston.transports.Console()]
});

module.exports = logger;