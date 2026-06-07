FROM node:20-slim

# Set session path environment variable
ENV SESSION_PATH=/opt/render/project/src/auth_session

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD [ "npm", "start" ]
