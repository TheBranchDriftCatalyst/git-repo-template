FROM node:22-slim

# yarn, not pnpm: this repo standardises on yarn for app dependencies.
# Node 22 ships corepack, so yarn needs no global npm install — and dropping
# the old `npm install -g pnpm@11` layer also drops pnpm-workspace.yaml, which
# existed only to hold `allowBuilds` for esbuild's postinstall.
RUN corepack enable

WORKDIR /app

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

COPY . .

EXPOSE 5173
# vite dev server (not a prod build) — this is the inner dev loop
CMD ["yarn", "dev", "--host", "0.0.0.0"]
