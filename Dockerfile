# syntax=docker/dockerfile:1

# BASE
FROM node:22.14.0-alpine AS base
WORKDIR /usr/src/app
COPY package*.json ./

# DEV
FROM base AS dev
RUN --mount=type=cache,target=/root/.npm \
    npm config set update-notifier false && \
    npm install --include=dev --legacy-peer-deps --prefer-offline
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

# DEPS
FROM base AS deps
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

# BUILD
FROM base AS build-deps
RUN --mount=type=cache,target=/root/.npm \
    npm install --include=dev --legacy-peer-deps
COPY . .
RUN npm run build

# FINAL
FROM base AS final
ENV NODE_ENV=production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 nextjs
USER nextjs

# Copy production dependencies
COPY --from=deps --chown=nextjs:nodejs /usr/src/app/node_modules ./node_modules

# Copy built assets
COPY --from=build-deps --chown=nextjs:nodejs /usr/src/app/.next/standalone ./
COPY --from=build-deps --chown=nextjs:nodejs /usr/src/app/.next/static ./.next/static
COPY --from=build-deps --chown=nextjs:nodejs /usr/src/app/public ./public

EXPOSE 3000
CMD ["node", "server.js"] 