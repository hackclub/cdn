# Use the official Bun image as base
FROM oven/bun:1

# install curl for coolify healthcheck
RUN apt-get update && apt-get install -y curl wget

# Set working directory
WORKDIR /app

# Copy package.json and bun.lockb (if exists)
COPY package*.json bun.lockb* ./

# Install dependencies
RUN bun install

# Copy the rest of the application
COPY . .

# Expose the port your Express server runs on
EXPOSE 3000

# Start the server
CMD ["bun", "run", "start"]
