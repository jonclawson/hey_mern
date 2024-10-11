# Create the main project directory
mkdir mern-docker-app
cd mern-docker-app

# Create client directory and files
mkdir -p client/public client/src
touch client/public/index.html
touch client/src/App.js client/src/index.js
touch client/Dockerfile client/package.json

# Create server directory and files
mkdir -p server/src/models
touch server/src/index.js
touch server/src/models/Message.js
touch server/Dockerfile server/package.json

# Create root level files
touch docker-compose.yml docker-compose.prod.yml .dockerignore

# Write content to files
cat << EOT > client/public/index.html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>MERN Docker App</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOT

cat << EOT > client/src/App.js
import React, { useState, useEffect } from 'react';

function App() {
  const [message, setMessage] = useState('');

  useEffect(() => {
    fetch('/api/message')
      .then(response => response.json())
      .then(data => setMessage(data.text));
  }, []);

  return (
    <div>
      <h1>MERN Docker App</h1>
      <p>{message}</p>
    </div>
  );
}

export default App;
EOT

cat << EOT > client/src/index.js
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOT

cat << EOT > client/package.json
{
  "name": "mern-docker-client",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  },
  "proxy": "http://server:5000"
}
EOT

cat << EOT > client/Dockerfile
# Development stage
FROM node:18 as development

WORKDIR /app

COPY package*.json ./
RUN npm install

EXPOSE 3000

CMD ["npm", "start"]

# Production stage
FROM node:18 as production

WORKDIR /app

COPY package*.json ./
RUN npm install --only=production

COPY . .

RUN npm run build

FROM nginx:alpine

COPY --from=production /app/build /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOT

cat << EOT > server/src/models/Message.js
const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  text: {
    type: String,
    required: true
  }
});

module.exports = mongoose.model('Message', messageSchema);
EOT

cat << EOT > server/src/index.js
const express = require('express');
const mongoose = require('mongoose');
const Message = require('./models/Message');

const app = express();
const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://mongo:27017/mern_docker_app';

mongoose.connect(MONGODB_URI)
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.error('MongoDB connection error:', err));

app.get('/api/message', async (req, res) => {
  try {
    let message = await Message.findOne();
    if (!message) {
      message = new Message({ text: 'Hello from the server!' });
      await message.save();
    }
    res.json(message);
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.listen(PORT, () => {
  console.log(\`Server running on port \${PORT}\`);
});
EOT

cat << EOT > server/package.json
{
  "name": "mern-docker-server",
  "version": "1.0.0",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.1.0"
  },
  "devDependencies": {
    "nodemon": "^2.0.22"
  }
}
EOT

cat << EOT > server/Dockerfile
FROM node:18

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 5000

CMD ["npm", "run", "dev"]
EOT

cat << EOT > docker-compose.yml
version: '3'
services:
  client:
    build:
      context: ./client
      target: development
    volumes:
      - ./client/src:/app/src
      - ./client/public:/app/public
    ports:
      - "3000:3000"
    environment:
      - CHOKIDAR_USEPOLLING=true
    depends_on:
      - server

  server:
    build: ./server
    volumes:
      - ./server/src:/app/src
    ports:
      - "5000:5000"
    environment:
      - MONGODB_URI=mongodb://mongo:27017/mern_docker_app
    depends_on:
      - mongo

  mongo:
    image: mongo:4.4
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db

volumes:
  mongodb_data:
EOT

cat << EOT > docker-compose.prod.yml
version: '3'
services:
  client:
    build:
      context: ./client
      target: production
    ports:
      - "80:80"
    depends_on:
      - server

  server:
    build: ./server
    ports:
      - "5000:5000"
    environment:
      - MONGODB_URI=mongodb://mongo:27017/mern_docker_app
    command: ["npm", "start"]
    depends_on:
      - mongo

  mongo:
    image: mongo:4.4
    volumes:
      - mongodb_data:/data/db

volumes:
  mongodb_data:
EOT

cat << EOT > .dockerignore
node_modules
npm-debug.log
EOT

echo "MERN Docker app structure and files have been created successfully with the requested changes!"
