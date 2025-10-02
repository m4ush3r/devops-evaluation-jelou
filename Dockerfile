# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Production stage
FROM node:18-alpine

# Create app directory with proper permissions
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application files
COPY --chown=nodejs:nodejs package*.json ./
COPY --chown=nodejs:nodejs index.js ./
COPY --chown=nodejs:nodejs public ./public

# Switch to non-root user
USER nodejs

EXPOSE 3000

# Use node directly instead of npm for better signal handling
CMD ["node", "index.js"]