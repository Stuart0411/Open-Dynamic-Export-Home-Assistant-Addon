# Base image with NodeJS (Pinned version for stability)
FROM node:14.21.3-alpine

# Set environment variables
ENV NODE_ENV=production
ARG REPOSITORY_URL

# Set working directory
WORKDIR /usr/src/app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --only=production \
    && npm cache clean --force

# Copy the rest of the application files
COPY . .

# Verify build output for dist folder creation
RUN npm run build && test -d dist

# Health check (adjust endpoint/path as necessary)
HEALTHCHECK CMD curl --fail http://localhost:3000/health || exit 1

# Expose the application port
EXPOSE 3000

# Replace default shell with ENTRYPOINT for improved signal handling
ENTRYPOINT ["npm", "start"]