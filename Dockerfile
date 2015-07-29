FROM node:0.12

EXPOSE 8080

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

RUN npm install -g grunt-cli
COPY package.json /usr/src/app/
RUN npm install
COPY . /usr/src/app
RUN grunt build

CMD [ "npm", "start" ]
