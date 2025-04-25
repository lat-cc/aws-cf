FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN npm run build

FROM node:22-alpine AS deploy
USER node
RUN mkdir /home/node/app 
WORKDIR /home/node/app
COPY --chown=node:node --from=build /app/dist ./dist
COPY --chown=node:node --from=build /app/package*.json ./
RUN npm ci
EXPOSE 3000

CMD ["node", "dist/main"]
