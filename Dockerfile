# --- Stage 1: build the Worker with Wrangler -----------------------
FROM node:25-alpine AS builder

WORKDIR /app

# Install dependencies & wrangler
COPY package*.json wrangler.toml ./
RUN npm ci

# Prepare workerd binary in builder to avoid npm presence in final image
RUN npm install -g @cloudflare/workerd-linux-64

# Copy source and build
COPY src ./src
RUN npx wrangler deploy --dry-run --outdir=dist

# --- Stage 2: minimal runtime with workerd -------------------------
FROM debian:bookworm-slim AS runtime

# Install ca-certificates for SSL
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy workerd binary from builder (no npm in runtime)
COPY --from=builder /usr/local/lib/node_modules/@cloudflare/workerd-linux-64/bin/workerd /usr/local/bin/workerd
RUN chmod +x /usr/local/bin/workerd && /usr/local/bin/workerd --version

WORKDIR /worker

# Bring in the compiled Worker bundle and config
COPY --from=builder /app/dist ./dist
COPY config.capnp ./config.capnp

# Expose the port workerd listens on
EXPOSE 8080

CMD ["workerd", "serve", "config.capnp"]
