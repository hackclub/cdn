const winston = require('winston');

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(winston.format.colorize(), winston.format.simple()),
    transports: [new winston.transports.Console()],
});

module.exports = logger;