# ── Stage 1: Build frontend ───────────────────────────────────────────────────
FROM node:20-alpine AS frontend-builder
WORKDIR /app
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build

# ── Stage 2: Build server ─────────────────────────────────────────────────────
FROM node:20-alpine AS server-builder
WORKDIR /app
COPY server/package.json server/package-lock.json ./
RUN npm ci
COPY server/ .
RUN npm run build

# ── Stage 3: Build MCP ────────────────────────────────────────────────────────
FROM node:20-alpine AS mcp-builder
WORKDIR /app
COPY mcp/package.json mcp/package-lock.json ./
RUN npm ci
COPY mcp/ .
RUN npm run build

# ── Stage 4: Runtime ──────────────────────────────────────────────────────────
FROM node:20-alpine
WORKDIR /app

# Server production dependencies
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev

# MCP production dependencies
COPY mcp/package.json mcp/package-lock.json ./mcp/
RUN npm ci --omit=dev --prefix mcp

# Server compiled output
COPY --from=server-builder /app/dist ./dist

# Frontend static files served by Fastify
COPY --from=frontend-builder /app/dist ./public

# MCP server
COPY --from=mcp-builder /app/dist ./mcp/dist

# Personas
COPY docs/personas/ ./personas/

# Data directory — mount a PVC here in Kubernetes
RUN mkdir -p /app/data

EXPOSE 3000 3001

CMD ["node", "dist/index.js"]
