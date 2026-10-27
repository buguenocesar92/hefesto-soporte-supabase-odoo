FROM node:24-bookworm-slim AS build
WORKDIR /app/portable
COPY portable/package.json ./package.json
RUN npm install --ignore-scripts --no-audit --no-fund
COPY app/page.tsx app/globals.css /app/app/
COPY lib /app/lib/
COPY portable/frontend ./frontend
COPY portable/vite.config.mts ./vite.config.mts
RUN npm run build
FROM node:24-bookworm-slim
ENV NODE_ENV=production PORT=3000 DATA_DIR=/data
WORKDIR /app
COPY --from=build /app/portable/dist ./portable/dist
COPY portable/server.mjs portable/storage.mjs ./portable/
COPY portable/tools ./portable/tools
COPY lib ./lib
RUN mkdir /data && chown node:node /data
USER node
VOLUME ["/data"]
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s CMD node -e "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "portable/server.mjs"]
