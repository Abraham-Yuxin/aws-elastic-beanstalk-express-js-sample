FROM node:16-bullseye
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev

COPY . .
ENV PORT=8081
EXPOSE 8081
CMD ["npm","start"]
